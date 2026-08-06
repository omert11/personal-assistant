#!/usr/bin/env bash
# PreToolUse/Bash guard — route expensive builds through the global `heavy` lock.
#
# Reads the PreToolUse payload on stdin and, when the command looks like a heavy
# build, rewrites it via hookSpecificOutput.updatedInput so it runs as
#   heavy $SHELL -c '<original command>'
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

# Already lock-aware -> never double-wrap. Matched at every position a command
# can start, not just the front: `cd x && heavy go test ...` wrapped again would
# have the outer heavy hold the slot its own inner heavy waits for. Only command
# position counts, so `docker build -t heavy .` and `grep heavy log.txt` are
# still classified normally.
if [[ $CMD =~ (^|[;\&\|\(][[:space:]]*)(([^[:space:]]*/)?heavy(\.sh)?|lockf|taskpolicy)[[:space:]] ]]; then
  exit 0
fi

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

# commit and push are cheap themselves, but their hooks are not: pre-commit runs
# linters and a lefthook pre-push happily starts `cargo test`. Those builds are
# invisible to this guard — it only sees the command Claude wrote — so the git
# verb that triggers them takes the slot on their behalf. Other verbs stay
# untouched: status/diff/log are instant and queueing them would only add latency.
QUEUE_RE='(^|[[:space:];&|(])git[[:space:]]+(commit|push)([[:space:]]|$)'

# Project- or machine-local overrides may redefine DEV_RE / HEAVY_RE / QUEUE_RE.
OVERRIDES="${HEAVY_PATTERNS:-$HOME/.config/heavy/patterns.sh}"
# shellcheck disable=SC1090
[ -f "$OVERRIDES" ] && . "$OVERRIDES"

emit() {
  # $1 = new command, $2 = force background (true/false), $3 = raise the timeout
  # Anything that can wait for a slot gets the Bash tool's maximum timeout: the
  # default 120000 ms is shorter than HEAVY_TIMEOUT, so a queued command would be
  # killed while it is still waiting in line and never run at all.
  printf '%s' "$INPUT" | jq -c \
    --arg cmd "$1" \
    --argjson bg "$2" \
    --argjson slow "$3" \
    '{hookSpecificOutput: {
        hookEventName: "PreToolUse",
        updatedInput: (.tool_input + {command: $cmd}
                       + (if $bg then {run_in_background: true} else {} end)
                       + (if $slow then {timeout: 600000} else {} end))
      }}'
  exit 0
}

QUOTED=$(printf '%s' "$INPUT" | jq -r '.tool_input.command | @sh')

# Re-run the command under the same shell that would have run it, not a fixed
# `bash`. macOS ships bash 3.2, which cannot parse a heredoc carrying an
# apostrophe inside $( ) — the exact shape of `git commit -m "$(cat <<'EOF'…)"`.
# Wrapping in bash would silently change the language the command is written in.
WRAP_SHELL="${SHELL:-/bin/bash}"
case $WRAP_SHELL in
  */bash|*/zsh|*/sh|*/dash|*/ksh) ;;   # anything exotic (fish, nushell) is not
  *) WRAP_SHELL=/bin/bash ;;           # POSIX enough to take -c '<command>'
esac

# Classify the command skeleton, not the raw text: heredoc bodies and quoted
# strings are data, not commands. `git commit -m "cargo build faster"` is a
# commit, not a build, and must not be backgrounded behind a slot.
# What a shell -c wrapper carries IS a command, so it is skeletonised too and
# appended as a second candidate.
CANDIDATES=$(printf '%s' "$CMD" | perl -0777 -e '
  my $s = do { local $/; <STDIN> };
  my @out = ($s);
  # -c may be bundled with other flags (bash -lc, zsh -ic) or preceded by them
  # (sh -eu -c); all of them still carry a command as their payload.
  while ($s =~ /(?:^|[\s;&|(])(?:ba|z)?sh\s+(?:-\S+\s+)*-[a-zA-Z]*c\s+(?:\x27([^\x27]*)\x27|"((?:[^"\\]|\\.)*)")/gs) {
    push @out, defined $1 ? $1 : $2;
  }
  for my $c (@out) {
    $c =~ s/<<-?\s*([\x27"])([A-Za-z_]\w*)\1.*?^\s*\2\s*$/ HEREDOC /gms;
    $c =~ s/<<-?\s*([A-Za-z_]\w*).*?^\s*\1\s*$/ HEREDOC /gms;
    # One left-to-right pass, like the shell itself: whichever quote opens first
    # closes first. Two separate passes would let an apostrophe inside a double
    # quoted string ("worktree\x27ye ...") shift every following range.
    $c =~ s/\x27[^\x27]*\x27|"(?:[^"\\]|\\.)*"/ QSTR /g;
    $c =~ s/(^|[\s;&|(])#[^\n]*/$1 COMMENT /g;
    print "$c\n";
  }
')

if [[ $CANDIDATES =~ $DEV_RE ]]; then
  emit "$HEAVY_BIN --low '$WRAP_SHELL' -c $QUOTED" false false
fi

if [[ $CANDIDATES =~ $HEAVY_RE ]]; then
  emit "$HEAVY_BIN '$WRAP_SHELL' -c $QUOTED" true true
fi

# Commits are cheap themselves, but their pre-commit hooks run linters and
# formatters. Queue them behind builds without ever blocking them: --queue runs
# the command unslotted once the ceiling is hit, and stays in the foreground so
# the commit output comes back inline.
if [[ $CANDIDATES =~ $QUEUE_RE ]]; then
  emit "$HEAVY_BIN --queue '$WRAP_SHELL' -c $QUOTED" false true
fi

exit 0
