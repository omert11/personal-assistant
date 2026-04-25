#!/bin/bash
# Stop hook — Oturumda kayda değer aktivite varsa Obsidian'ın daily note'una
# tek satır özet append'ler. Sessiz çalışır (Claude'a soru sormaz),
# obsidian CLI aktif değilse veya değer bulunmazsa skip eder.
#
# stop-obsidian-remind.sh ile birlikte çalışır:
#   - remind.sh: kayda değer bilgi varsa Claude'a obsidian-writer çağır dedirtir (block decision)
#   - daily.sh : oturumun bir-cümle özetini daily note'a append eder (sessiz)

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Obsidian CLI aktif mi? IPC çağrıları 2s timeout ile sarılır.
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

CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$CWD" ] || exit 0
[ -f "$CWD/CLAUDE.local.md" ] || exit 0

OBSIDIAN_FOLDER=$(grep -oE "Obsidian Folder:\s*\K.+" "$CWD/CLAUDE.local.md" 2>/dev/null | head -1)
[ -n "$OBSIDIAN_FOLDER" ] || exit 0

LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
MSG_LEN=${#LAST_MSG}

# Çok kısa ya da işlem yapılmamış oturumlarda skip
[ "$MSG_LEN" -gt 200 ] || exit 0

# İlk 280 karakter (twitter-vari kısa özet)
SUMMARY=$(echo "$LAST_MSG" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-280)
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

CONTENT="- ${TIME} [[${OBSIDIAN_FOLDER}/index|${OBSIDIAN_FOLDER}]]: ${SUMMARY}"

obs daily:append content="$CONTENT" >/dev/null || true

exit 0
