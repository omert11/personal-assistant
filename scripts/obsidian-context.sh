#!/bin/bash
# SessionStart hook — Obsidian index.md'den frontmatter + basliklari dump eder.
# Amac: main agent'a proje belleginin MOC'unu goster, detay gerekirse Read ile alsin.

CWD="$PWD"
[ -f "$CWD/CLAUDE.local.md" ] || exit 0

OBSIDIAN_FOLDER=$(grep -oE "Obsidian Folder:\s*\K.+" "$CWD/CLAUDE.local.md" 2>/dev/null | head -1)
[ -n "$OBSIDIAN_FOLDER" ] || exit 0

VAULT="${OBSIDIAN_VAULT:-$HOME/Documents/ObsidianVault}"
INDEX="$VAULT/$OBSIDIAN_FOLDER/index.md"

[ -f "$INDEX" ] || exit 0

echo "=== Obsidian MOC ($OBSIDIAN_FOLDER/index.md) ==="
# Frontmatter (ilk --- blogu)
awk '/^---$/{c++; print; if(c==2) exit; next} c==1{print}' "$INDEX"
echo ""
# Basliklar (h1/h2/h3)
grep -E "^#{1,3} " "$INDEX"
echo ""
echo "=== Detay: Read \"$INDEX\" veya ilgili [[wikilink]]ler ==="
