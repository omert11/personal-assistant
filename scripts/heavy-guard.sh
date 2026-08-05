#!/usr/bin/env bash
# PreToolUse/Bash guard — route expensive builds through the global `heavy` lock.
#
# Reads the PreToolUse payload on stdin and, when the command looks like a heavy
# build, rewrites it via hookSpecificOutput.updatedInput so it runs as
#   heavy bash -c '<original command>'
# and in the background (lock waiting can exceed the Bash tool's 10 min ceiling).
#
# Long-lived dev servers are rewritten to `heavy --low ...` instead: background
# QoS, no lock — a dev server holds the lock for hours and would jam the queue.
#
# Anything else passes through untouched (exit 0, no stdout).
set -uo pipefail

INPUT=$(cat)

command -v jq >/dev/null 2>&1 || exit 0
[ "$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')" = "Bash" ] || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
[ -n "$CMD" ] || exit 0

# Already lock-aware -> never double-wrap. Matches the wrapper as a command
# word only, so an unrelated `grep heavy log.txt` still gets classified.
case "$CMD" in
  heavy\ *|*/heavy\ *|*heavy.sh\ *|*lockf\ *|*taskpolicy\ *) exit 0 ;;
esac

HEAVY_BIN="$HOME/.local/bin/heavy"
if [ ! -x "$HEAVY_BIN" ]; then
  HEAVY_BIN="${CLAUDE_PLUGIN_ROOT:-}/scripts/heavy.sh"
  [ -x "$HEAVY_BIN" ] || exit 0
fi

# Long-lived processes: compile once, then run for hours. Lock-free.
DEV_RE='(^|[[:space:];&|(])(cargo[[:space:]]+(run|watch)|cargo[[:space:]]+tauri[[:space:]]+dev|air([[:space:]]|$)|go[[:space:]]+run|(npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?(dev|start|watch)|next[[:space:]]+dev|vite([[:space:]]|$)|nodemon|(python|python3)[[:space:]]+manage\.py[[:space:]]+runserver)'

# Finite, CPU-hungry builds. Whitelist on purpose: `cargo tree`, `go env`,
# `cargo fmt` and friends are cheap and must stay instant.
HEAVY_RE='(^|[[:space:];&|(])(cargo[[:space:]]+(build|test|check|clippy|bench|doc|install|fix|nextest)|cargo[[:space:]]+tauri[[:space:]]+(build|android|ios)|go[[:space:]]+(build|test|vet|install|generate)|(npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?build|(next|vite|tsc|turbo|webpack|esbuild)[[:space:]]+build|xcodebuild|\./gradlew|gradle[[:space:]]|cmake[[:space:]]+--build|docker[[:space:]]+(build|buildx)|maturin[[:space:]]+(build|develop))'

# Project- or machine-local overrides may redefine DEV_RE / HEAVY_RE.
OVERRIDES="${HEAVY_PATTERNS:-$HOME/.config/heavy/patterns.sh}"
# shellcheck disable=SC1090
[ -f "$OVERRIDES" ] && . "$OVERRIDES"

emit() {
  # $1 = new command, $2 = force background (true/false)
  # Backgrounded builds also get the Bash tool's maximum timeout: the default
  # 120000 ms would cut a long compile short if it is ever applied.
  printf '%s' "$INPUT" | jq -c \
    --arg cmd "$1" \
    --argjson bg "$2" \
    '{hookSpecificOutput: {
        hookEventName: "PreToolUse",
        updatedInput: (.tool_input + {command: $cmd}
                       + (if $bg then {run_in_background: true, timeout: 600000} else {} end))
      }}'
  exit 0
}

QUOTED=$(printf '%s' "$INPUT" | jq -r '.tool_input.command | @sh')

if [[ $CMD =~ $DEV_RE ]]; then
  emit "$HEAVY_BIN --low bash -c $QUOTED" false
fi

if [[ $CMD =~ $HEAVY_RE ]]; then
  emit "$HEAVY_BIN bash -c $QUOTED" true
fi

exit 0
