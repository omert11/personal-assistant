#!/bin/bash
# SessionStart hook — Bugünün ve dünün Obsidian daily note'larından
# kısa özet kontekste basar. Continuity için: dünden devam eden işler,
# son oturumda yazılan satırlar görünür olur.
#
# obsidian-context.sh ile birlikte:
#   - obsidian-context.sh: PROJE klasörünün index.md MOC'u (frontmatter + başlıklar)
#   - session-obsidian-daily.sh: GLOBAL daily note'lar (bugün + dün), ilk 100 satır

INPUT=$(cat 2>/dev/null)

# session_start damgasi: oturumun GERCEK baslangic zamanini state tablosuna yaz.
# Stop hook'lardaki 5dk-yas kontrolu bu zamana bakar; ilk Stop'ta degil burada
# damgalanmali ki tek-turlu/kisa oturumlar da dogru degerlendirilsin. Obsidian
# kapali olsa bile damga atilir (asagidaki CLI kontrolunden once).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/hook-state.sh" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/hook-state.sh"
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
  [ -n "$SESSION_ID" ] && hook_state_touch_session "$SESSION_ID"
fi

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

# NOT: `obsidian daily:read` çağrılmaz — Daily Notes core plugin'i o günün
# notu yoksa otomatik boş dosya oluşturuyor (auto-create yan etkisi). Bunun
# yerine dosyayı doğrudan filesystem'den okuyoruz; yoksa sessizce atlıyoruz.
VAULT_PATH=$(obs vault info=path)
[ -n "$VAULT_PATH" ] || exit 0

# Tek tarih için daily note dosyasını yaygın konumlarda arar, varsa head'ler.
print_daily() {
  local label="$1" d="$2" found=""
  for candidate in "Daily/${d}.md" "Daily Notes/${d}.md" "${d}.md"; do
    if [ -s "$VAULT_PATH/$candidate" ]; then
      found="$VAULT_PATH/$candidate"
      break
    fi
  done
  if [ -n "$found" ]; then
    echo "=== Obsidian Daily — ${label} (${d}) ==="
    head -100 "$found"
    echo ""
  fi
}

TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d 2>/dev/null)
print_daily "Bugün" "$TODAY"
[ -n "$YESTERDAY" ] && print_daily "Dün" "$YESTERDAY"

echo "=== Detay: obsidian daily:read veya Read <vault>/Daily/<date>.md ==="
exit 0
