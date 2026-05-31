#!/bin/bash
# UserPromptSubmit hook — Obsidian Folder tanimli projede, kullanici prompt'una
# iki davranisi additionalContext olarak enjekte eder:
#   1. ARAMA: arastirma/inceleme gerekiyorsa once obsidian-searcher ile vault'a bak.
#   2. KAYIT: cevabi urettikten sonra, ogrenilen/kaydedilmesi gereken bilgi varsa
#      obsidian-writer'i background calistirip kaydet (Stop-block yerine — block
#      ek tur + "error" gorunumu yaratiyordu; bu yontem ciktiyla beraber sessizce
#      arka planda baslatir).
#
# Sessiz calisir: Obsidian Folder yoksa veya CLAUDE.local.md yoksa hicbir sey
# enjekte etmez. Trivial prompt'lari (cok kisa / selamlasma) atlar. KAYIT
# hatirlatmasi geciktirme kuralina tabidir: ayni oturumda en fazla REMIND_INTERVAL
# (5 dk) bir kez. Eski stop-obsidian-remind.sh'in (Stop-block) yerini alir.

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

# 1. ARAMA hatirlatmasi — her non-trivial prompt'ta.
HINT="Bu projenin Obsidian vault klasoru var: \`${OBSIDIAN_FOLDER}\`. Eger bu istek icin bir arastirma/inceleme yapilacaksa, ONCE \`obsidian-searcher\` agent'ini (run_in_background: true) cagirip vault'a bak — daha once benzer durumlar yasanmis, ogrenilen bilgiler ve elde edilen sonuclar (bilinen bug, DB/credential, mimari karar, calisan komut, cozum prosedurleri) kayitli olabilir. Arastirma yapmaktan cekinme; gecmis kayit cogu zaman sifirdan ugrasmaktan hizli ve dogru sonuc verir. Bulgu varsa baglam olarak kullan. Sadece selamlasma/trivial isteklerde arama yapma."

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
  HINT="${HINT}  ||  Ayrica son cevabini urettikten sonra sunu dusun: su an kaydetmem gereken, bu oturumda ogrendigim kayda deger bir bilgi var mi (yeni bir karar, calisan komut, credential/sunucu, tekrar eden pattern, cozulen bug)? Varsa cevabinla beraber, ek bir calistirma beklemeden, \`obsidian-writer\` agent'ini (run_in_background: true, MODE: append, TARGET: ~/Documents/ObsidianVault/${OBSIDIAN_FOLDER}) gizlice arka planda baslatip kaydet ve kullaniciya tek cumleyle ne kaydettigini bildir. Kayda deger bir sey yoksa hicbir sey yapma, normal akisa devam et."
fi

jq -n --arg ctx "$HINT" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
exit 0
