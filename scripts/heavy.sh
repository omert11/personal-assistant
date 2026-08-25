#!/usr/bin/env bash
# heavy — cap how many expensive builds run at once, machine-wide.
#
#   heavy <cmd...>         take a build slot, wait in line if all are busy
#   heavy --low <cmd...>   background QoS, no slot (long-lived dev servers)
#   heavy --status         which slots are busy and with what
#
# The pool has a fixed base width and a soft ceiling. When every lane is taken
# but the CPU has stayed under HEAVY_CPU_CEIL for a whole HEAVY_GROW_WINDOW, a
# busy pool is not a busy machine, so one extra lane opens — one per clean
# window, up to HEAVY_MAX_SLOTS, past which the queue is hard.
#
# That window is a fact about the machine, not about the run asking. Slot
# holders append CPU samples to a shared history, so an arrival reads the last
# HEAVY_GROW_WINDOW seconds and decides at once instead of standing in line to
# re-observe an idleness that already happened.
#
# macOS ships no flock(1); /usr/bin/lockf is the system equivalent. lockf holds
# one file, so N concurrent slots are N lock files tried round-robin. Slots are
# shared by every language and project: a Rust build and a Go build compete for
# the same slots instead of fighting for cores.
set -uo pipefail

# Machine-local defaults (a 16 GB laptop may want a single slot where the shipped
# default is 2). Only these knobs are read from the file; HEAVY_CONFIG itself is
# not, since it already picked the file.
CONFIG_VARS='HEAVY_SLOTS HEAVY_TIMEOUT HEAVY_STATE_DIR HEAVY_LOG
HEAVY_MAX_SLOTS HEAVY_GROW_WINDOW HEAVY_CPU_CEIL'
CONFIG="${HEAVY_CONFIG:-$HOME/.config/heavy/config.sh}"
if [ -f "$CONFIG" ]; then
  # Read in a subshell: a config that aborts (unset var under set -u, a stray
  # `exit`) must not take heavy down with it. The guard rewrites every build into
  # a backgrounded `heavy bash -c ...`, so dying here would turn a typo in the
  # config into a silent no-op that still reports success.
  cfg_values=$(
    set +u
    for v in $CONFIG_VARS; do unset "$v"; done  # only file-set values come back
    # shellcheck disable=SC1090
    . "$CONFIG" >/dev/null 2>&1 || exit 1
    for v in $CONFIG_VARS; do
      eval "val=\${$v:-}"
      [ -n "$val" ] && printf '%s=%s\n' "$v" "$val"
    done
    exit 0
  ) || [ "${1:-}" = "__exec" ] ||  # the inner re-entry would repeat the warning
    printf '[heavy] %s okunamadi, varsayilanlar kullaniliyor\n' "$CONFIG" >&2
  # An env var on the call always wins; the file only fills in what is unset.
  while IFS='=' read -r key val; do
    [ -n "$key" ] || continue
    eval "cur=\${$key:-}"
    [ -n "$cur" ] || eval "$key=\$val"
  done <<EOF
$cfg_values
EOF
fi

STATE_DIR="${HEAVY_STATE_DIR:-$HOME/.cache}"
LOCK_FILE="$STATE_DIR/heavy-build.lock"
HOLDER_FILE="$STATE_DIR/heavy-build.current"
WAIT_FILE="$STATE_DIR/heavy-build.waiting"
CPU_FILE="$STATE_DIR/heavy-build.cpu"
WAIT_TIMEOUT="${HEAVY_TIMEOUT:-1200}"
SLOTS="${HEAVY_SLOTS:-2}"
MAX_SLOTS="${HEAVY_MAX_SLOTS:-4}"    # hard ceiling for the side lanes
GROW_WINDOW="${HEAVY_GROW_WINDOW:-30}"  # seconds of idle CPU that buy one lane
CPU_CEIL="${HEAVY_CPU_CEIL:-90}"     # busy percent that counts as bottlenecked

# A non-numeric or sub-minimum value would leave the round-robin loop with
# nothing to try, so the command would never run.
num_or() {  # $1 = value, $2 = fallback, $3 = minimum
  case "$1" in
    ''|*[!0-9]*) printf '%s' "$2"; return ;;
  esac
  [ "$1" -lt "$3" ] && { printf '%s' "$2"; return; }
  printf '%s' "$1"
}
SLOTS=$(num_or "$SLOTS" 1 1)
MAX_SLOTS=$(num_or "$MAX_SLOTS" 4 1)
GROW_WINDOW=$(num_or "$GROW_WINDOW" 30 1)
CPU_CEIL=$(num_or "$CPU_CEIL" 90 1)
# A ceiling under the base would shrink the pool instead of extending it.
[ "$MAX_SLOTS" -lt "$SLOTS" ] && MAX_SLOTS=$SLOTS
# How wide this run currently believes the pool is; grows, never shrinks.
SLOT_LIMIT=$SLOTS
POLL_INTERVAL=2

# lockf exits 75 (EX_TEMPFAIL) when it cannot take the lock. A wrapped command
# may legitimately exit 75 too, so __exec remaps that to 175 and the caller maps
# it back — otherwise a command exiting 75 would look like a busy slot and be
# retried, running it twice.
RC_LOCK_BUSY=75
RC_CMD_75=175

mkdir -p "$STATE_DIR"

usage() {
  cat >&2 <<'EOF'
kullanim:
  heavy <komut...>         bos bir derleme slotu al, hepsi doluysa sirada bekle
  heavy --queue <komut...> slot bekle ama tavan dolunca yine de calistir
  heavy --low <komut...>   slot almadan arka plan QoS'unda calistir
  heavy --status           slotlar dolu mu + kuyrukta kim bekliyor
  heavy --stats            kosu logunun ozeti (bekleme orani, load, mod dagilimi)
ortam:
  HEAVY_SLOTS       taban slot sayisi (varsayilan 2)
  HEAVY_MAX_SLOTS   ek slotlarla cikilabilecek tavan (varsayilan 4)
  HEAVY_GROW_WINDOW ek slot icin gereken bos-CPU suresi, saniye (varsayilan 30)
  HEAVY_CPU_CEIL    bu yuzdenin ustundeki CPU darbogaz sayilir (varsayilan 90)
  HEAVY_TIMEOUT     bekleme tavani, saniye (varsayilan 1200)
  HEAVY_STATE_DIR   kilit + holder dosyalarinin dizini (varsayilan ~/.cache)
  HEAVY_CONFIG      makine-lokal ayar dosyasi (varsayilan ~/.config/heavy/config.sh)
  HEAVY_LOG         kosu logu dosyasi (varsayilan <state>/heavy-build.log, off ile kapali)
EOF
}

LOG_FILE="${HEAVY_LOG:-$STATE_DIR/heavy-build.log}"

# Redact anything that looks like a secret before it lands in a file that
# outlives the run — commands routinely carry API keys inline.
redact() {
  sed -E 's/([A-Za-z_]*(KEY|TOKEN|SECRET|PASSWORD|PASS)=)[^[:space:]]*/\1***/g'
}

# One line per slotted run: how long it queued, how long it ran, and what the
# machine looked like meanwhile. This is the evidence for whether a dynamic slot
# count would have paid off and where its threshold should sit — guessing at one
# without this data is how you get a rule that fires on the wrong signal.
log_run() {
  # $1 = mode, $2 = queued seconds, $3 = ran seconds, $4 = exit code, $5.. = command
  [ "$LOG_FILE" = off ] && return 0
  mode=$1 queued=$2 ran=$3 rc=$4
  shift 4
  # Create it private before the first append: a plain >> would make it 0644 for
  # as long as it takes to reach the chmod, and the lines carry command text.
  [ -f "$LOG_FILE" ] || (umask 077; : >> "$LOG_FILE") 2>/dev/null
  loadnow=$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk '{print $1","$2}')
  printf '%s\tmode=%s\tslots=%s\tqueued=%ss\tran=%ss\trc=%s\tload=%s\tcwd=%s\tcmd=%s\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$mode" "${SLOT_LIMIT:-$SLOTS}" "$queued" "$ran" "$rc" \
    "${loadnow:-?}" "$PWD" "$(printf '%s' "$*" | tr '\n' ' ' | cut -c1-200)" \
    | redact >> "$LOG_FILE" 2>/dev/null
  # Keep the tail rather than growing without bound; this is sampling data, not
  # an audit trail. Rotation runs under its own lock so two concurrent heavy
  # runs cannot shred the file; whoever loses the lock just skips this round.
  # Lines appended between the tail and the mv are lost, which is acceptable
  # for sampling and why the threshold is far above a normal day's volume.
  if [ "$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)" -gt 524288 ] &&
     command -v lockf >/dev/null 2>&1; then
    lockf -kst 0 "$LOG_FILE.rotate" sh -c '
      tmp=$1.$$.tmp
      tail -n 2000 "$1" > "$tmp" 2>/dev/null && chmod 600 "$tmp" && mv "$tmp" "$1"
    ' sh "$LOG_FILE" 2>/dev/null
  fi
}

# Run a command in the foreground of this process tree while still being able to
# log afterwards. `exec` would be simpler but leaves nothing to log from; a bare
# background job would detach stdin (POSIX redirects async jobs to /dev/null,
# which breaks `git commit -F -`) and would not pass signals on, orphaning a
# build when the wrapper is killed.
run_and_log() {
  # $1 = mode, $2 = seconds already spent queueing, $3.. = command
  mode=$1 queued=$2
  shift 2
  started=$SECONDS
  exec 3<&0
  "$@" <&3 &
  child=$!
  exec 3<&-
  trap 'kill -TERM "$child" 2>/dev/null' INT TERM
  wait "$child"
  rc=$?
  trap - INT TERM
  log_run "$mode" "$queued" "$((SECONDS - started))" "$rc" "$@"
  exit $rc
}

slot_is_free() {
  lockf -kst 0 "$LOCK_FILE.$1" true 2>/dev/null
}

# Busy CPU percent averaged over $1 seconds, empty when it cannot be read.
# iostat's own interval doubles as the poll sleep, so sampling costs no extra
# wall-clock while queued. Idle is always the fourth field from the end — the
# three load averages trail it — whatever the disk count on the line.
cpu_busy() {
  iostat -c 2 -w "$1" 2>/dev/null |
    awk 'END { if (NF > 4 && $(NF-3) ~ /^[0-9.]+$/) printf "%d", 100 - $(NF-3) }'
}

# Take one sample and append it to the shared history. Lines are short and
# opened O_APPEND, so concurrent samplers interleave safely rather than needing
# a lock; a duplicate second costs nothing since the reader only asks whether
# any sample in the window was over the ceiling.
cpu_sample_append() {
  busy=$(cpu_busy "$1")
  [ -n "$busy" ] || return 1
  [ -f "$CPU_FILE" ] || (umask 077; : >> "$CPU_FILE") 2>/dev/null
  printf '%s %s\n' "$(date +%s)" "$busy" >> "$CPU_FILE" 2>/dev/null
  # Bounded by rewrite rather than by rotation: the file is tiny and only the
  # recent tail is ever read.
  if [ "$(wc -l < "$CPU_FILE" 2>/dev/null || echo 0)" -gt 400 ]; then
    tmp="$CPU_FILE.$$.tmp"
    if tail -n 200 "$CPU_FILE" > "$tmp" 2>/dev/null; then
      chmod 600 "$tmp" 2>/dev/null
      mv "$tmp" "$CPU_FILE" 2>/dev/null || rm -f "$tmp"
    else
      rm -f "$tmp"
    fi
  fi
}

# What the shared history says about the last $1 seconds:
#   clean  window fully covered, fresh, no gaps, every sample under the ceiling
#   busy   at least one sample at or over the ceiling
#   thin   not enough history to judge — absent, stale, short or holed
# `thin` is deliberately not `clean`: missing evidence is not evidence of an
# idle machine, so a run that finds it falls back to filling the window itself.
cpu_window_verdict() {
  [ -f "$CPU_FILE" ] || { printf thin; return; }
  awk -v now="$(date +%s)" -v win="$1" -v ceil="$CPU_CEIL" \
      -v gap="$((POLL_INTERVAL * 3))" '
    ($1 + 0) >= now - win {
      t = $1 + 0
      n++
      if (($2 + 0) >= ceil) busy = 1
      if (t > newest) newest = t
      if (!oldest || t < oldest) oldest = t
      if (prev && t - prev > gap) holes = 1
      prev = t
    }
    END {
      if (busy)                       { print "busy"; exit }
      if (!n || now - newest > gap)   { print "thin"; exit }
      if (oldest > now - win + gap)   { print "thin"; exit }
      if (holes)                      { print "thin"; exit }
      print "clean"
    }' "$CPU_FILE" 2>/dev/null || printf thin
}

holder_line() {
  sed -n 's/^cmd=//p' "$HOLDER_FILE.$1" 2>/dev/null | head -1
}

case "${1:-}" in
  --status)
    # Lanes above the base only exist while something holds them, but they are
    # listed either way: a run that grew into slot 3 is invisible otherwise.
    for i in $(seq 1 "$MAX_SLOTS"); do
      if [ "$i" -le "$SLOTS" ]; then kind=taban; else kind=ek; fi
      if slot_is_free "$i"; then
        printf 'slot %s/%s (%s): bos\n' "$i" "$MAX_SLOTS" "$kind"
      else
        printf 'slot %s/%s (%s): dolu\n' "$i" "$MAX_SLOTS" "$kind"
        [ -f "$HOLDER_FILE.$i" ] && sed 's/^/  /' "$HOLDER_FILE.$i"
      fi
    done
    now=$(date +%s)
    queued=0
    # Waiters register themselves before sleeping. A killed waiter leaves its
    # file behind, so anything whose pid is gone is swept here rather than
    # reported as an eternal queue entry.
    for f in "$WAIT_FILE".*; do
      [ -f "$f" ] || continue
      wpid=${f##*.}
      if ! kill -0 "$wpid" 2>/dev/null; then
        rm -f "$f"
        continue
      fi
      queued=$((queued + 1))
      since=$(sed -n 's/^since=//p' "$f")
      printf 'sirada %s: %ss bekliyor (%s)\n' \
        "$queued" "$((now - ${since:-now}))" "$(sed -n 's/^mode=//p' "$f")"
      grep -v '^since=' "$f" | grep -v '^mode=' | sed 's/^/  /'
    done
    [ "$queued" -eq 0 ] && printf 'sirada: bos\n'
    exit 0
    ;;
  --stats)
    # Summarise the run log: this is what a dynamic slot count would have to
    # justify itself against — how much time is actually lost queueing, and at
    # what load.
    [ -f "$LOG_FILE" ] || { printf 'log yok: %s\n' "$LOG_FILE"; exit 0; }
    awk -F'\t' '
      { delete f                      # else a short line inherits the last record
        for (i = 1; i <= NF; i++) {
          p = index($i, "=")          # split() would cut a value at its first =
          if (p) f[substr($i, 1, p - 1)] = substr($i, p + 1)
        }
        if (!("queued" in f)) next
        runs++
        q = f["queued"]; sub(/s$/, "", q); q += 0   # force numeric compare
        r = f["ran"];    sub(/s$/, "", r); r += 0
        totq += q; totr += r
        if (f["load"] ~ /^[0-9]/) { split(f["load"], l, ","); totl += l[1]; loadn++ }
        if (q > maxq) { maxq = q; maxcmd = f["cmd"] }
        if (q > 0) waited++
        mode[f["mode"]]++
      }
      END {
        if (!runs) { print "log bos"; exit }
        printf "kosu:             %d\n", runs
        printf "kuyrukta bekledi: %d (%.0f%%)\n", waited, waited * 100 / runs
        printf "toplam bekleme:   %ds (ort %.1fs/kosu)\n", totq, totq / runs
        printf "toplam calisma:   %ds (ort %.1fs/kosu)\n", totr, totr / runs
        printf "bekleme/calisma:  %.1f%%\n", (totr ? totq * 100 / totr : 0)
        if (loadn) printf "ort load (1dk):   %.2f (%d kayit)\n", totl / loadn, loadn
        else       printf "ort load (1dk):   olculemedi\n"
        printf "en uzun bekleme:  %ds -- %s\n", maxq, substr(maxcmd, 1, 80)
        printf "mod dagilimi:    "
        for (m in mode) printf " %s=%d", m, mode[m]
        printf "\n"
      }' "$LOG_FILE"
    exit 0
    ;;
  --low)
    shift
    [ $# -gt 0 ] || { usage; exit 64; }
    if [ -x /usr/sbin/taskpolicy ]; then
      exec /usr/sbin/taskpolicy -b "$@"
    fi
    exec "$@"
    ;;
  --queue)
    # Wait for a slot like a normal run, but never skip the command: when the
    # ceiling is hit, run it unslotted. For work that must not be blocked by a
    # long build (a commit and its pre-commit hooks) yet should not race it either.
    shift
    [ $# -gt 0 ] || { usage; exit 64; }
    QUEUE_FALLBACK=1
    MODE=queue
    ;;
  __exec)
    # Internal: runs with the slot's lock already held by the parent lockf.
    shift
    slot="$1"
    shift
    # The slot is ours now, so drop the parent's queue entry — otherwise the
    # same run would be listed as both running and waiting.
    [ -n "${HEAVY_WAITER:-}" ] && rm -f "$HEAVY_WAITER"
    printf 'pid=%s\nstarted=%s\ncwd=%s\ncmd=%s\n' \
      "$$" "$(date '+%Y-%m-%d %H:%M:%S')" "$PWD" "$*" | redact > "$HOLDER_FILE.$slot"
    # Keep the shared window fed for as long as this lane is held. A full pool
    # always implies at least one holder, so the history exists exactly when
    # somebody needs to judge it. Duplicate samplers are harmless.
    #
    # The loop runs until the trap kills it: a failed sample costs one reading,
    # never the sampler. Letting a transient iostat hiccup end it would leave
    # this lane held for the rest of a long build while the window it was
    # supposed to fill goes thin, quietly freezing growth for everybody else.
    sampler=
    if [ "${HEAVY_NO_SAMPLER:-0}" != 1 ] && command -v iostat >/dev/null 2>&1; then
      ( while :; do cpu_sample_append "$POLL_INTERVAL" || sleep "$POLL_INTERVAL"; done ) &
      sampler=$!
    fi
    trap 'rm -f "$HOLDER_FILE.$slot"; [ -n "$sampler" ] && kill "$sampler" 2>/dev/null' EXIT
    export HEAVY_SLOT_HELD=1
    "$@"
    rc=$?
    [ $rc -eq $RC_LOCK_BUSY ] && rc=$RC_CMD_75
    exit $rc
    ;;
  -h|--help|"")
    usage
    exit 64
    ;;
esac

if [ "${HEAVY_SLOT_HELD:-0}" = 1 ]; then
  # Already running inside a slot (a wrapped command that calls `heavy` again).
  # Queueing here would wait for a slot this very process tree is holding —
  # deadlock on a single-slot machine. Reuse the slot instead.
  run_and_log nested 0 "$@"
fi

if ! command -v lockf >/dev/null 2>&1; then
  # No lockf (non-macOS): degrade to running unserialized rather than failing.
  exec "$@"
fi

announced=0
SECONDS=0

last_grant=

while :; do
  for i in $(seq 1 "$SLOT_LIMIT"); do
    queued=$SECONDS
    HEAVY_WAITER="$WAIT_FILE.$$" lockf -kst 0 "$LOCK_FILE.$i" "$0" __exec "$i" "$@"
    rc=$?
    # Runs that only started because a lane was granted are tagged, so --stats
    # can show what the growth actually bought.
    runmode="${MODE:-slot}"
    [ "$i" -gt "$SLOTS" ] && runmode="$runmode-grown"
    case $rc in
      $RC_LOCK_BUSY) ;;              # slot busy, try the next one
      $RC_CMD_75)
        log_run "$runmode" "$queued" "$((SECONDS - queued))" 75 "$@"
        exit 75 ;;                   # the command itself exited 75
      *)
        log_run "$runmode" "$queued" "$((SECONDS - queued))" "$rc" "$@"
        exit $rc ;;
    esac
  done

  if [ "$SECONDS" -ge "$WAIT_TIMEOUT" ]; then
    if [ "${QUEUE_FALLBACK:-0}" -eq 1 ]; then
      printf '[heavy] %ss icinde slot acilmadi, komut slotsuz calistiriliyor\n' "$WAIT_TIMEOUT" >&2
      rm -f "$WAIT_FILE.$$"
      run_and_log queue-fallback "$SECONDS" "$@"
    fi
    printf '[heavy] %ss icinde slot acilmadi, komut CALISTIRILMADI\n' "$WAIT_TIMEOUT" >&2
    log_run timeout "$SECONDS" 0 75 "$@"
    exit 75
  fi

  # Side lane. Every lane is taken, but a busy pool is not a busy machine. The
  # verdict comes from history the holders already recorded, so an arrival that
  # finds the machine idle grows and runs *now* — waiting out a second window
  # would only re-measure an idleness that has already been measured.
  #
  # Gradualism lives in last_grant, not in the wait: the first lane is free the
  # instant the window reads clean, each further lane costs GROW_WINDOW of wall
  # clock after the previous grant. At MAX_SLOTS the queue is hard.
  if [ "$SLOT_LIMIT" -lt "$MAX_SLOTS" ] &&
     { [ -z "$last_grant" ] ||
       [ "$(($(date +%s) - last_grant))" -ge "$GROW_WINDOW" ]; }; then
    if [ "$(cpu_window_verdict "$GROW_WINDOW")" = clean ]; then
      SLOT_LIMIT=$((SLOT_LIMIT + 1))
      last_grant=$(date +%s)
      printf '[heavy] CPU son %ss boyunca %%%s altinda, ek slot: %s/%s\n' \
        "$GROW_WINDOW" "$CPU_CEIL" "$SLOT_LIMIT" "$MAX_SLOTS" >&2
      continue                        # retry the wider pool at once, no sleep
    fi
  fi

  if [ "$announced" -eq 0 ]; then
    # Register in the queue so `heavy --status` can show who is waiting on what.
    printf 'pid=%s\nsince=%s\nmode=%s\ncwd=%s\ncmd=%s\n' \
      "$$" "$(date +%s)" \
      "$([ "${QUEUE_FALLBACK:-0}" -eq 1 ] && echo queue || echo slot)" \
      "$PWD" "$*" | redact > "$WAIT_FILE.$$"
    # EXIT does the cleanup; INT/TERM must also *stop* the wait loop. A handler
    # that only deletes the file would return into the loop and keep waiting,
    # invisible to --status but still ready to run the build.
    trap 'rm -f "$WAIT_FILE.$$"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    printf '[heavy] %s slotun hepsi dolu:\n' "$SLOT_LIMIT" >&2
    for i in $(seq 1 "$SLOT_LIMIT"); do
      printf '[heavy]   slot %s: %s\n' "$i" "$(holder_line "$i")" >&2
    done
    printf '[heavy] sirada bekleniyor (tavan %ss)...\n' "$WAIT_TIMEOUT" >&2
    announced=1
  fi

  # No lane this round. Sampling doubles as the poll sleep and feeds the shared
  # window, so a `thin` history fills itself in — after GROW_WINDOW of quiet
  # this run's own samples are what turn the verdict clean. A `busy` verdict
  # clears the same way: the offending sample ages out of the window.
  if [ "$SLOT_LIMIT" -lt "$MAX_SLOTS" ]; then
    cpu_sample_append "$POLL_INTERVAL" || sleep "$POLL_INTERVAL"
  else
    sleep "$POLL_INTERVAL"
  fi
done
