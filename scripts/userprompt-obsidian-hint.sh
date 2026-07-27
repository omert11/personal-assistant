#!/bin/bash
# UserPromptSubmit hook — Obsidian Folder tanimli projede, kullanici prompt'una
# iki davranisi additionalContext olarak enjekte eder:
#   1. ARAMA: arastirma/inceleme gerekiyorsa once obsidian-search skill'i ile
#      vault'a bak (ana agent arar, subagent devri yok).
#   2. KAYIT: cevabi urettikten sonra kalici bir bilgi/karar dogduysa
#      obsidian-write skill'ini cagirip yaz (Stop-block yerine — block ek tur +
#      "error" gorunumu yaratiyordu).
#      NOT: kriterin kanonik tanimi rules/obsidian.md + skills/obsidian-write
#      icindedir — kriter degisirse HINT, skill ve docs/index.html birlikte
#      guncellenir.
#
# Sessiz calisir: Obsidian Folder yoksa veya CLAUDE.local.md yoksa hicbir sey
# enjekte etmez. Trivial prompt'lari (cok kisa / selamlasma) atlar. KAYIT
# hatirlatmasi geciktirme kuralina tabidir: ayni oturumda en fazla REMIND_INTERVAL
# (5 dk) bir kez.
#
# HINT skill'lerin akisini TEKRARLAMAZ — yalnizca "ne zaman hangi skill" der.
# Akisin tamami skill dosyalarindadir; skill cagrilinca yuklenir.

INPUT=$(cat 2>/dev/null)

CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$CWD" ] || exit 0
[ -f "$CWD/CLAUDE.local.md" ] || exit 0

# Obsidian Folder cikarimi — ortak helper varsa onu kullan, yoksa inline fallback.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBSIDIAN_FOLDER=""
if [ -f "$SCRIPT_DIR/hook-state.sh" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/hook-state.sh"
fi
if command -v hook_obsidian_folder >/dev/null 2>&1; then
  OBSIDIAN_FOLDER=$(hook_obsidian_folder "$CWD/CLAUDE.local.md")
else
  OBSIDIAN_FOLDER=$(grep -E "Obsidian.*Folder[^:]*:" "$CWD/CLAUDE.local.md" 2>/dev/null \
    | grep -vE "^[[:space:]]*>" | grep -v "init-check" | head -1 \
    | sed -E 's/.*Folder[^:]*:[[:space:]]*//; s/^[`*[:space:]]*//; s/[`*|[:space:]]*$//')
fi
[ -n "$OBSIDIAN_FOLDER" ] || exit 0

# Trivial prompt'larda enjekte etme — cok kisa istekler (selamlasma, "evet", "ok",
# tek kelime) icin gereksiz. ~15 karakter alti atla.
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ "${#PROMPT}" -ge 15 ] || exit 0

# 1. ARAMA hatirlatmasi — her non-trivial prompt'ta. KESIN KURAL: sadece gorev
#    basinda degil, is akisi icinde her ne zaman ek performans/efor gerektiren bir
#    is dogarsa (sorun/hata cozme, arastirma/inceleme, dogrulama/teyit, log analizi,
#    bir karar/komut/credential arama) o anda once vault'a bakilmalidir.
HINT="Bu projenin Obsidian vault klasoru var: \`${OBSIDIAN_FOLDER}\`. KESIN KURAL: gorev basinda degil, is akisinin HERHANGI bir aninda ek efor gerektiren bir is dogdugunda — sorun/hata cozerken, arastirirken/incelerken, bir durumu dogrularken, log analizinde veya bir karar/komut/credential/mimari bilgi ararken — O ANDA \`obsidian-search\` skill'ini cagir. Onceki oturumlar ayni durumu yasamis ve bulgusunu yazmis olabilir; vault'a bakmak sifirdan ugrasmaktan ucuz ve genelde daha dogru. Bulgu cikarsa baglam olarak kullan; SONUC BOSSA normal akisina devam et ve is bitince \`obsidian-write\` ile yaz. Trivial/selamlasma isteklerinde arama yapma."

# 2. KAYIT hatirlatmasi — geciktirme kuralina tabi (5 dk'da bir). state tablosunda
# last_learning_hook ile takip edilir.
REMIND_INTERVAL="${REMIND_INTERVAL:-300}"  # 5 dakika
ADD_SAVE=0
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
if command -v hook_state_get >/dev/null 2>&1 && [ -n "$SESSION_ID" ]; then
  hook_state_touch_session "$SESSION_ID"
  LAST_LEARNING=$(hook_state_get "$SESSION_ID" last_learning_hook)
  NOW=$(date +%s)
  if [ "$LAST_LEARNING" = "0" ] || [ "$((NOW - LAST_LEARNING))" -ge "$REMIND_INTERVAL" ]; then
    ADD_SAVE=1
    hook_state_set "$SESSION_ID" last_learning_hook "$NOW"
  fi
else
  # State helper yoksa geciktirme yapilamaz; yine de kayit hatirlatmasini ekle.
  ADD_SAVE=1
fi

# NOT: HINT tek satir tutulur — jq --arg ham newline'i JSON string icinde escape
# ETMEZ, cok satirli deger gecersiz JSON uretir. Bolumler bosluk/ayraçla birlesir.
if [ "$ADD_SAVE" -eq 1 ]; then
  HINT="${HINT}  ||  KAYIT: bu oturumda kalici bir BILGI (sistem/servis gercekte nasil calisiyor; credential/sunucu/endpoint dahil) veya KARAR dogduysa \`obsidian-write\` skill'ini cagir — kriter ve akis o skill'de. Supheliysen YAZMA. BEKLETME: devam eden isin varsa yazmayi hemen baslatma; tum isler bitince yaz, bitmediyse kalan isleri raporlarken bekleyen yazma islemini de listele ki kullanici karar verebilsin."
fi

jq -n --arg ctx "$HINT" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
exit 0
