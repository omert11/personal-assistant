#!/bin/bash
# Rules loader for personal-assistant plugin
# SessionStart hook — stdout is injected into Claude's context
#
# Strategy: copy rule files to ~/.claude/rules/ so Claude can Read them
# by a stable path, and emit a SHORT index (filename + summary) to stdout
# instead of concatenating ~19KB of rule content. Avoids Claude Code's
# ~2KB hook preview truncation.

set -e

RULES_SRC="${CLAUDE_PLUGIN_ROOT}/rules"
LOCAL_RULES_SRC="${CLAUDE_PLUGIN_ROOT}/local-rules"
RULES_DST="$HOME/.claude/rules"

mkdir -p "$RULES_DST"

# Copy new/changed rules. Plain cp -u covers this cheaply; on macOS cp
# doesn't have -u so we compare mtimes via cmp if cp -u unsupported.
copy_if_newer() {
  local src=$1
  local dst="$RULES_DST/$(basename "$src")"
  if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
    cp "$src" "$dst"
  fi
}

[ -d "$RULES_SRC" ] && for f in "$RULES_SRC"/*.md; do
  [ -f "$f" ] && copy_if_newer "$f"
done

[ -d "$LOCAL_RULES_SRC" ] && for f in "$LOCAL_RULES_SRC"/*.md; do
  [ -f "$f" ] && copy_if_newer "$f"
done

# Build the index
echo "# Active Rules"
echo ""
echo "Rules materialised at \`~/.claude/rules/\`. Read a specific file when its topic becomes relevant to the current task."
echo ""

for f in "$RULES_DST"/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  # Prefer the first H2 heading, fall back to the first H1 or first non-empty line
  desc=$(grep -m1 '^## ' "$f" 2>/dev/null | sed 's/^## //' | cut -c1-80)
  [ -z "$desc" ] && desc=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' | cut -c1-80)
  [ -z "$desc" ] && desc=$(grep -m1 '^[A-Za-zÇĞİÖŞÜçğıöşü]' "$f" 2>/dev/null | cut -c1-80)
  [ -z "$desc" ] && desc="(no description)"
  printf -- "- **%s** — %s\n" "$name" "$desc"
done

exit 0
