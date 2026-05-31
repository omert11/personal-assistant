#!/bin/bash
# Stop hook — Oturumda kayda değer aktivite varsa Obsidian'ın daily note'una
# tek satır özet append'ler. Sessiz çalışır (Claude'a soru sormaz),
# obsidian CLI aktif değilse veya değer bulunmazsa skip eder.
#
# NOT: Öğrenilen bilgiyi kaydetme hatırlatması artık Stop'ta değil,
# UserPromptSubmit hook'unda (userprompt-obsidian-hint.sh) yapılıyor — block
# decision'ın yarattığı ek tur + "error" görünümünü önlemek için.

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Seyreltme: bu hook oturum basina YALNIZCA 1 kez yazar. session_id state
# tablosunda last_daily_hook doluysa atla (her Stop'ta tekrar append'i engeller).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/hook-state.sh" ]; then
  # Helper yoksa seyreltme yapilamaz; eski (her Stop) davranisa duser, hata verme.
  SESSION_ID=""
else
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/hook-state.sh"
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
fi
DAILY_MIN_AGE="${DAILY_MIN_AGE:-300}"  # oturum baslangicindan en az 5 dk gecmeli
if [ -n "$SESSION_ID" ]; then
  hook_state_touch_session "$SESSION_ID"
  # Zaten yazildiysa atla (oturumda 1 kez)
  if [ "$(hook_state_get "$SESSION_ID" last_daily_hook)" != "0" ]; then
    exit 0
  fi
  # Oturum cok yeniyse (< 5 dk) atla. session_start GERCEK baslangic (SessionStart
  # hook'unda damgalanir). Damga yoksa (0) gate uygulanmaz — yasi bilemeyiz, yazmaya
  # izin ver (eski guvenli davranis; tek-turlu oturum kaybini onler).
  SESSION_START=$(hook_state_get "$SESSION_ID" session_start)
  if [ "$SESSION_START" != "0" ] && [ -n "$SESSION_START" ]; then
    if [ "$(($(date +%s) - SESSION_START))" -lt "$DAILY_MIN_AGE" ]; then
      exit 0
    fi
  fi
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

# OBSIDIAN_FOLDER cikarimi ortak helper'da (hook-state.sh). Helper source
# edilemediyse (yukarida [ -f ] guard) fonksiyon tanimsiz olur — o durumda skip.
command -v hook_obsidian_folder >/dev/null 2>&1 || exit 0
OBSIDIAN_FOLDER=$(hook_obsidian_folder "$CWD/CLAUDE.local.md")
[ -n "$OBSIDIAN_FOLDER" ] || exit 0

LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
MSG_LEN=${#LAST_MSG}

# Çok kısa ya da işlem yapılmamış oturumlarda skip
[ "$MSG_LEN" -gt 200 ] || exit 0

# Transcript'in fiziksel yolu — hem ozet kaynagi (aiTitle) hem daily satirina link.
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# Ozet metni oncelik sirasi:
#   1. customTitle — kullanicinin /rename ile bilincli koydugu baslik (en spesifik)
#   2. aiTitle     — Claude'un urettigi otomatik baslik
#   3. son asistan mesajinin ilk 280 karakteri (eski davranis, fallback)
# Ikisi de transcript'te {"customTitle":"..."} / {"aiTitle":"..."} satirlarinda;
# son (en guncel) deger alinir. jq'ya tum transcript'i deserialize ettirmemek icin
# once grep ile ilgili satirlari suzeriz (transcript MB'larca olabilir, hot path).
SUMMARY=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  SUMMARY=$(grep '"customTitle"' "$TRANSCRIPT" 2>/dev/null \
    | jq -r 'select(.customTitle? != null and .customTitle != "") | .customTitle' 2>/dev/null \
    | tail -1)
  if [ -z "$SUMMARY" ]; then
    SUMMARY=$(grep '"aiTitle"' "$TRANSCRIPT" 2>/dev/null \
      | jq -r 'select(.aiTitle? != null and .aiTitle != "") | .aiTitle' 2>/dev/null \
      | tail -1)
  fi
fi
if [ -z "$SUMMARY" ]; then
  SUMMARY="$LAST_MSG"
fi
# Tek satira indir + ilk 280 karakter — hem aiTitle hem fallback ayni sanitize'den
# gecer (aiTitle'da gomulu newline daily note markdown listesini bozmasin).
SUMMARY=$(printf '%s' "$SUMMARY" | tr '\n\t' '  ' | sed 's/  */ /g' | cut -c1-280)

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

CONTENT="- ${TIME} [[${OBSIDIAN_FOLDER}/index|${OBSIDIAN_FOLDER}]]: ${SUMMARY}"
[ -n "$TRANSCRIPT" ] && CONTENT="${CONTENT} — [transcript](file://${TRANSCRIPT})"

obs daily:append content="$CONTENT" >/dev/null || true

# Basarili yazimdan sonra damgala — bu oturumda bir daha tetiklenmez.
[ -n "$SESSION_ID" ] && hook_state_set "$SESSION_ID" last_daily_hook "$(date +%s)"

exit 0
