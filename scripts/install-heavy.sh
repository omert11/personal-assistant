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

# Build-tool shims: ~/.local/bin/<tool> -> heavy-shim.sh, so builds started from
# scripts or detached jobs still take a heavy slot. A symlink already there is
# kept as the shim's real binary; a real file is left alone.
SHIM="${CLAUDE_PLUGIN_ROOT}/scripts/heavy-shim.sh"
REAL_DIR="$HOME/.local/share/heavy/real"
[ -f "$SHIM" ] && chmod +x "$SHIM" 2>/dev/null || true
for tool in go pnpm npm npx yarn; do
  [ -f "$SHIM" ] || break
  t="$DST_DIR/$tool"
  if [ -L "$t" ]; then
    cur=$(readlink "$t")
    [ "$cur" = "$SHIM" ] && continue
    case "$cur" in */heavy-shim.sh) ln -sf "$SHIM" "$t"; continue ;; esac
    case "$cur" in /*) ;; *) cur="$DST_DIR/$cur" ;; esac
    mkdir -p "$REAL_DIR"
    ln -sf "$cur" "$REAL_DIR/$tool"
    ln -sf "$SHIM" "$t"
  elif [ ! -e "$t" ]; then
    command -v "$tool" >/dev/null 2>&1 || continue
    ln -s "$SHIM" "$t"
  fi
done

exit 0
