#!/usr/bin/env bash
# heavy — run one expensive build at a time, machine-wide.
#
#   heavy <cmd...>         take the global build lock, wait in line if busy
#   heavy --low <cmd...>   background QoS, no lock (long-lived dev servers)
#   heavy --status         who holds the lock right now
#
# macOS ships no flock(1); /usr/bin/lockf is the system equivalent.
# The lock is a single file shared by every language and project, so a Rust
# build and a Go build queue behind each other instead of fighting for cores.
set -uo pipefail

STATE_DIR="${HEAVY_STATE_DIR:-$HOME/.cache}"
LOCK_FILE="$STATE_DIR/heavy-build.lock"
HOLDER_FILE="$STATE_DIR/heavy-build.current"
WAIT_TIMEOUT="${HEAVY_TIMEOUT:-1200}"

mkdir -p "$STATE_DIR"

usage() {
  cat >&2 <<'EOF'
kullanim:
  heavy <komut...>        global derleme kilidini al, doluysa sirada bekle
  heavy --low <komut...>  kilide girmeden arka plan QoS'unda calistir
  heavy --status          kilidi kim tutuyor
ortam:
  HEAVY_TIMEOUT     bekleme tavani, saniye (varsayilan 1200)
  HEAVY_STATE_DIR   kilit + holder dosyalarinin dizini (varsayilan ~/.cache)
EOF
}

# Non-blocking probe. Only used for the "who is ahead of me" message, so a
# race here costs nothing.
lock_is_free() {
  lockf -kst 0 "$LOCK_FILE" true 2>/dev/null
}

holder_line() {
  sed -n 's/^cmd=//p' "$HOLDER_FILE" 2>/dev/null | head -1
}

case "${1:-}" in
  --status)
    if lock_is_free; then
      echo "heavy: kilit bos"
    else
      echo "heavy: kilit dolu"
      [ -f "$HOLDER_FILE" ] && cat "$HOLDER_FILE"
    fi
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
    # Internal: runs with the lock already held by the parent lockf.
    shift
    printf 'pid=%s\nstarted=%s\ncwd=%s\ncmd=%s\n' \
      "$$" "$(date '+%Y-%m-%d %H:%M:%S')" "$PWD" "$*" > "$HOLDER_FILE"
    trap 'rm -f "$HOLDER_FILE"' EXIT
    "$@"
    exit $?
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

if ! lock_is_free; then
  printf '[heavy] baska bir agir derleme calisiyor: %s\n' "$(holder_line || true)" >&2
  printf '[heavy] sirada bekleniyor (tavan %ss)...\n' "$WAIT_TIMEOUT" >&2
fi

lockf -kst "$WAIT_TIMEOUT" "$LOCK_FILE" "$0" __exec "$@"
rc=$?

# lockf exits 75 (EX_TEMPFAIL) when the timeout expires without the lock.
if [ $rc -eq 75 ]; then
  printf '[heavy] kilit %ss icinde alinamadi, komut CALISTIRILMADI: %s\n' \
    "$WAIT_TIMEOUT" "$(holder_line || true)" >&2
fi

exit $rc
