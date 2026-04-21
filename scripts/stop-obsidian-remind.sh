#!/bin/bash
# Stop hook — main agent'a Obsidian'a yeni ogrenilen bilgi ekleme hatirlatmasi yollar.
# Her Stop'ta bir kez tetiklenir; stop_hook_active=true ise loop kirmak icin sessiz cikar.

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
OBSIDIAN_FOLDER=""
if [ -n "$CWD" ] && [ -f "$CWD/CLAUDE.local.md" ]; then
  OBSIDIAN_FOLDER=$(grep -oE "Obsidian Folder:\s*\K.+" "$CWD/CLAUDE.local.md" 2>/dev/null | head -1)
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

jq -n --arg folder "$OBSIDIAN_FOLDER" '{
  decision: "block",
  reason: ("Bu oturumda kullanici tarafindan paylasilan veya birlikte ogrenilen yeni bir bilgi (sunucu/API key, teknik karar, calisan komut, tekrar eden pattern vb.) var mi degerlendir. Varsa Task tool ile obsidian-writer agent''ini MODE: append ile cagir - TARGET: ~/Documents/ObsidianVault/" + $folder + ", content: ogrenilen bilginin ozeti, topic: kisa baslik. Obsidian-writer gerekirse yeni not olusturur veya mevcut notu gunceller ve index.md MOC''una link ekler. Yoksa kisaca \"kaydedilecek yeni bilgi yok\" de ve bitir. Bu kontrolu sadece bir kez yap, tekrar etme.")
}'
exit 0
