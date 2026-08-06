#!/usr/bin/env bash
# heavy — cap how many expensive builds run at once, machine-wide.
#
#   heavy <cmd...>         take a build slot, wait in line if all are busy
#   heavy --low <cmd...>   background QoS, no slot (long-lived dev servers)
#   heavy --status         which slots are busy and with what
#
# macOS ships no flock(1); /usr/bin/lockf is the system equivalent. lockf holds
# one file, so N concurrent slots are N lock files tried round-robin. Slots are
# shared by every language and project: a Rust build and a Go build compete for
# the same slots instead of fighting for cores.
set -uo pipefail

# Machine-local defaults (a 16 GB laptop may want a single slot where the shipped
# default is 2). Only these knobs are read from the file; HEAVY_CONFIG itself is
# not, since it already picked the file.
CONFIG_VARS='HEAVY_SLOTS HEAVY_TIMEOUT HEAVY_STATE_DIR HEAVY_LOG'
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
WAIT_TIMEOUT="${HEAVY_TIMEOUT:-1200}"
SLOTS="${HEAVY_SLOTS:-2}"
# A non-numeric or sub-1 slot count would leave the round-robin loop with
# nothing to try, so the command would never run.
case "$SLOTS" in
  ''|*[!0-9]*) SLOTS=1 ;;
  *) [ "$SLOTS" -lt 1 ] && SLOTS=1 ;;
esac
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
  HEAVY_SLOTS       ayni anda kosacak agir derleme sayisi (varsayilan 2)
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
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$mode" "$SLOTS" "$queued" "$ran" "$rc" \
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

holder_line() {
  sed -n 's/^cmd=//p' "$HOLDER_FILE.$1" 2>/dev/null | head -1
}

case "${1:-}" in
  --status)
    for i in $(seq 1 "$SLOTS"); do
      if slot_is_free "$i"; then
        printf 'slot %s/%s: bos\n' "$i" "$SLOTS"
      else
        printf 'slot %s/%s: dolu\n' "$i" "$SLOTS"
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
    trap 'rm -f "$HOLDER_FILE.$slot"' EXIT
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

while :; do
  for i in $(seq 1 "$SLOTS"); do
    queued=$SECONDS
    HEAVY_WAITER="$WAIT_FILE.$$" lockf -kst 0 "$LOCK_FILE.$i" "$0" __exec "$i" "$@"
    rc=$?
    case $rc in
      $RC_LOCK_BUSY) ;;              # slot busy, try the next one
      $RC_CMD_75)
        log_run "${MODE:-slot}" "$queued" "$((SECONDS - queued))" 75 "$@"
        exit 75 ;;                   # the command itself exited 75
      *)
        log_run "${MODE:-slot}" "$queued" "$((SECONDS - queued))" "$rc" "$@"
        exit $rc ;;
    esac
  done

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
    printf '[heavy] %s slotun hepsi dolu:\n' "$SLOTS" >&2
    for i in $(seq 1 "$SLOTS"); do
      printf '[heavy]   slot %s: %s\n' "$i" "$(holder_line "$i")" >&2
    done
    printf '[heavy] sirada bekleniyor (tavan %ss)...\n' "$WAIT_TIMEOUT" >&2
    announced=1
  fi

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

  sleep "$POLL_INTERVAL"
done
