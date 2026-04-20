#!/bin/bash
# SessionStart: current proje için MemPalace wake-up yükler.
# Wing adını ~/.claude/projects/<encoded>/mempalace.yaml'dan okur.
# mempalace yoksa veya yaml yoksa → global wake-up fallback → sessiz exit.

command -v mempalace >/dev/null 2>&1 || exit 0

CWD_ENCODED=$(echo "$PWD" | sed 's|/|-|g')
YAML="$HOME/.claude/projects/$CWD_ENCODED/mempalace.yaml"

WING=""
if [ -f "$YAML" ]; then
  WING=$(grep -m1 '^wing:' "$YAML" 2>/dev/null | awk '{print $2}' | tr -d '"')
fi

if [ -n "$WING" ]; then
  mempalace wake-up --wing "$WING" 2>/dev/null || exit 0
else
  mempalace wake-up 2>/dev/null || exit 0
fi
