#!/bin/bash
# Stop hook — main agent'a Obsidian'a yeni ogrenilen bilgi ekleme hatirlatmasi yollar.
# Her Stop'ta bir kez tetiklenir; stop_hook_active=true ise loop kirmak icin sessiz cikar.

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Seyreltme: bu hatirlatma en fazla 15 dakikada bir tetiklenir. session_id state
# tablosunda last_learning_hook'tan REMIND_INTERVAL saniye gecmediyse sessizce cik.
# (Her Stop'ta block edip context kirletmesini engeller.)
REMIND_INTERVAL="${REMIND_INTERVAL:-900}"  # 15 dakika
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/hook-state.sh" ]; then
  # Helper yoksa seyreltme yapilamaz; eski (her Stop) davranisa duser, hata verme.
  SESSION_ID=""
else
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/hook-state.sh"
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
fi
if [ -n "$SESSION_ID" ]; then
  hook_state_touch_session "$SESSION_ID"
  LAST_LEARNING=$(hook_state_get "$SESSION_ID" last_learning_hook)
  if [ "$LAST_LEARNING" != "0" ]; then
    NOW=$(date +%s)
    if [ "$((NOW - LAST_LEARNING))" -lt "$REMIND_INTERVAL" ]; then
      exit 0
    fi
  fi
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
OBSIDIAN_FOLDER=""
# OBSIDIAN_FOLDER cikarimi ortak helper'da (hook-state.sh). Helper source
# edilemediyse fonksiyon tanimsiz olur — o durumda OBSIDIAN_FOLDER bos kalir.
if [ -n "$CWD" ] && [ -f "$CWD/CLAUDE.local.md" ] && command -v hook_obsidian_folder >/dev/null 2>&1; then
  OBSIDIAN_FOLDER=$(hook_obsidian_folder "$CWD/CLAUDE.local.md")
fi

if [ -z "$OBSIDIAN_FOLDER" ]; then
  exit 0
fi

# Filter: sadece kayda deger yanitlarda tetikle
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
MSG_LEN=${#LAST_MSG}

# Kisa yanit (<500 char) ve ogrenme ipucu yoksa atla
if [ "$MSG_LEN" -lt 500 ]; then
  if ! echo "$LAST_MSG" | grep -qiE "(ogren|kaydet|kural|not al|hatirla|yeni bilgi|API key|token|sunucu|ssh|password|credential|karar)"; then
    exit 0
  fi
fi

# Block etmeden once damgala — 15 dakika boyunca tekrar tetiklenmez.
[ -n "$SESSION_ID" ] && hook_state_set "$SESSION_ID" last_learning_hook "$(date +%s)"

jq -n --arg folder "$OBSIDIAN_FOLDER" '{
  decision: "block",
  reason: ("Bu oturumda kayda deger yeni bilgi (karar/komut/credential/pattern) varsa obsidian-writer agent''ini background calistirip " + $folder + " altina kaydet. Yoksa hicbir sey yapma, normal akisa devam et.")
}'
exit 0
