#!/bin/bash
# Rules + local skills loader for personal-assistant plugin
# SessionStart hook — materialises:
#   rules/*.md          -> ~/.claude/rules/<name>.md
#   local-skills/<name>/ -> ~/.claude/skills/<name>/   (gitignored; credentials)
#
# Claude Code loads both user-level dirs natively, so this script prints
# nothing: any stdout would duplicate content already in context. Its only job
# is copy + prune. Each destination keeps a manifest so pruning only touches
# entries this plugin created (e.g. ctx7's context7.md is never removed).

set -e

RULES_SRC="${CLAUDE_PLUGIN_ROOT}/rules"
SKILLS_SRC="${CLAUDE_PLUGIN_ROOT}/local-skills"
RULES_DST="$HOME/.claude/rules"
SKILLS_DST="$HOME/.claude/skills"

# Guard: without CLAUDE_PLUGIN_ROOT the sources resolve to "/rules" and
# "/local-skills", which do not exist. Pruning would then see an empty source
# set and delete every plugin-managed entry. Bail out before touching anything.
if [ ! -d "$RULES_SRC" ] && [ ! -d "$SKILLS_SRC" ]; then
  echo "load-rules: no source found (CLAUDE_PLUGIN_ROOT unset or wrong); nothing loaded." >&2
  exit 0
fi

# prune <dst-dir> <current-names> — remove manifest entries no longer in the
# source, then rewrite the manifest.
prune() {
  local dst=$1 current=$2 manifest="$1/.personal-assistant-manifest" name
  if [ -f "$manifest" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      printf '%s' "$current" | grep -qxF "$name" || rm -rf "${dst:?}/$name"
    done < "$manifest"
  fi
  printf '%s' "$current" | sort -u > "$manifest"
}

# --- rules ---------------------------------------------------------------
mkdir -p "$RULES_DST"
CURRENT=""
if [ -d "$RULES_SRC" ]; then
  for f in "$RULES_SRC"/*.md; do
    [ -f "$f" ] || continue
    dst="$RULES_DST/$(basename "$f")"
    if [ ! -f "$dst" ] || [ "$f" -nt "$dst" ]; then
      cp "$f" "$dst"
    fi
    CURRENT="$CURRENT$(basename "$f")
"
  done
fi
prune "$RULES_DST" "$CURRENT"

# --- local skills ----------------------------------------------------------
mkdir -p "$SKILLS_DST"
MANAGED=""
[ -f "$SKILLS_DST/.personal-assistant-manifest" ] && MANAGED=$(cat "$SKILLS_DST/.personal-assistant-manifest")
CURRENT=""
if [ -d "$SKILLS_SRC" ]; then
  for d in "$SKILLS_SRC"/*/; do
    [ -f "$d/SKILL.md" ] || continue
    name=$(basename "$d")
    dst="$SKILLS_DST/$name"
    # Never overwrite a skill this plugin did not create.
    if [ -e "$dst" ] && ! printf '%s' "$MANAGED" | grep -qxF "$name"; then
      echo "load-rules: ~/.claude/skills/$name exists and is not plugin-managed; skipped." >&2
      continue
    fi
    rm -rf "$dst"
    cp -R "$d" "$dst"
    CURRENT="$CURRENT$name
"
  done
fi
prune "$SKILLS_DST" "$CURRENT"

exit 0
