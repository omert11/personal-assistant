#!/bin/bash
# SessionStart hook — Bugünün ve dünün Obsidian daily note'larından
# kısa özet kontekste basar. Continuity için: dünden devam eden işler,
# son oturumda yazılan satırlar görünür olur.
#
# obsidian-context.sh ile birlikte:
#   - obsidian-context.sh: PROJE klasörünün index.md MOC'u (frontmatter + başlıklar)
#   - session-obsidian-daily.sh: GLOBAL daily note'lar (bugün + dün), ilk 100 satır

# Obsidian CLI aktif mi? Tüm IPC çağrıları 2s timeout ile sarılır —
# Obsidian app hung/loading ise SessionStart bloke olmasın.
if ! command -v obsidian >/dev/null 2>&1; then
  exit 0
fi

if command -v timeout >/dev/null 2>&1; then
  obs() { command timeout 2 obsidian "$@" 2>/dev/null; }
elif command -v gtimeout >/dev/null 2>&1; then
  obs() { command gtimeout 2 obsidian "$@" 2>/dev/null; }
else
  obs() { obsidian "$@" 2>/dev/null; }
fi

if ! obs vault info=name >/dev/null; then
  exit 0
fi

DAILY_TODAY=$(obs daily:read)
[ -z "$DAILY_TODAY" ] || {
  echo "=== Obsidian Daily — Bugün ($(date +%Y-%m-%d)) ==="
  echo "$DAILY_TODAY" | head -100
  echo ""
}

VAULT_PATH=$(obs vault info=path)
if [ -n "$VAULT_PATH" ]; then
  YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d 2>/dev/null)
  YDAILY=""
  for candidate in "Daily/${YESTERDAY}.md" "Daily Notes/${YESTERDAY}.md" "${YESTERDAY}.md"; do
    if [ -f "$VAULT_PATH/$candidate" ]; then
      YDAILY="$VAULT_PATH/$candidate"
      break
    fi
  done

  if [ -n "$YDAILY" ]; then
    echo "=== Obsidian Daily — Dün ($YESTERDAY) ==="
    head -100 "$YDAILY"
    echo ""
  fi
fi

echo "=== Detay: obsidian daily:read veya Read <vault>/Daily/<date>.md ==="
exit 0
