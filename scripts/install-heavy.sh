#!/usr/bin/env bash
# SessionStart hook — make `heavy` callable from the terminal and from solo.yml.
# Symlinks ~/.local/bin/heavy at the plugin's script so plugin updates carry over.
# Silent by design: SessionStart stdout lands in Claude's context.
set -eu

SRC="${CLAUDE_PLUGIN_ROOT:-}/scripts/heavy.sh"
[ -f "$SRC" ] || exit 0

chmod +x "$SRC" 2>/dev/null || true

DST_DIR="$HOME/.local/bin"
DST="$DST_DIR/heavy"

mkdir -p "$DST_DIR"

# Only manage our own symlink; never clobber a real file the user put there.
if [ -L "$DST" ]; then
  [ "$(readlink "$DST")" = "$SRC" ] || ln -sf "$SRC" "$DST"
elif [ ! -e "$DST" ]; then
  ln -s "$SRC" "$DST"
fi

exit 0
