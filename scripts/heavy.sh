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
CONFIG_VARS='HEAVY_SLOTS HEAVY_TIMEOUT HEAVY_STATE_DIR'
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
  heavy <komut...>        bos bir derleme slotu al, hepsi doluysa sirada bekle
  heavy --low <komut...>  slot almadan arka plan QoS'unda calistir
  heavy --status          slotlar dolu mu, hangi komutla
ortam:
  HEAVY_SLOTS       ayni anda kosacak agir derleme sayisi (varsayilan 2)
  HEAVY_TIMEOUT     bekleme tavani, saniye (varsayilan 1200)
  HEAVY_STATE_DIR   kilit + holder dosyalarinin dizini (varsayilan ~/.cache)
  HEAVY_CONFIG      makine-lokal ayar dosyasi (varsayilan ~/.config/heavy/config.sh)
EOF
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
  __exec)
    # Internal: runs with the slot's lock already held by the parent lockf.
    shift
    slot="$1"
    shift
    printf 'pid=%s\nstarted=%s\ncwd=%s\ncmd=%s\n' \
      "$$" "$(date '+%Y-%m-%d %H:%M:%S')" "$PWD" "$*" > "$HOLDER_FILE.$slot"
    trap 'rm -f "$HOLDER_FILE.$slot"' EXIT
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

if ! command -v lockf >/dev/null 2>&1; then
  # No lockf (non-macOS): degrade to running unserialized rather than failing.
  exec "$@"
fi

announced=0
SECONDS=0

while :; do
  for i in $(seq 1 "$SLOTS"); do
    lockf -kst 0 "$LOCK_FILE.$i" "$0" __exec "$i" "$@"
    rc=$?
    case $rc in
      $RC_LOCK_BUSY) ;;              # slot busy, try the next one
      $RC_CMD_75) exit 75 ;;         # the command itself exited 75
      *) exit $rc ;;
    esac
  done

  if [ "$announced" -eq 0 ]; then
    printf '[heavy] %s slotun hepsi dolu:\n' "$SLOTS" >&2
    for i in $(seq 1 "$SLOTS"); do
      printf '[heavy]   slot %s: %s\n' "$i" "$(holder_line "$i")" >&2
    done
    printf '[heavy] sirada bekleniyor (tavan %ss)...\n' "$WAIT_TIMEOUT" >&2
    announced=1
  fi

  if [ "$SECONDS" -ge "$WAIT_TIMEOUT" ]; then
    printf '[heavy] %ss icinde slot acilmadi, komut CALISTIRILMADI\n' "$WAIT_TIMEOUT" >&2
    exit 75
  fi

  sleep "$POLL_INTERVAL"
done
