#!/bin/bash
# Init Check Script — Cross-platform basic checks
# Dosya varlik + yapilandirma kontrolu yapar

MISSING=()
PROJECT_NAME=$(basename "$PWD")

# CLAUDE.md kontrolu
[ ! -f "CLAUDE.md" ] && MISSING+=("CLAUDE.md")

# CLAUDE.local.md kontrolu
if [ ! -f "CLAUDE.local.md" ]; then
  MISSING+=("CLAUDE.local.md")
else
  grep -q "Vikunja" CLAUDE.local.md 2>/dev/null || MISSING+=("Vikunja ID")
  grep -q "Solo" CLAUDE.local.md 2>/dev/null || MISSING+=("Solo ID")
fi

# Sonuc
if [ ${#MISSING[@]} -eq 0 ]; then
  echo "INIT_OK|$PROJECT_NAME"
else
  IFS=','; echo "INIT_MISSING|$PROJECT_NAME|${MISSING[*]}"
fi
