#!/bin/bash
# UserPromptSubmit hook — Obsidian Folder tanimli projede, her kullanici prompt'una
# kisa bir "once vault'ta ara" hatirlatmasi enjekte eder (additionalContext).
# Amac: somut gorev/sorunlarda main agent'i obsidian-searcher'a yonlendirmek —
# gecmiste yazilmis proje-spesifik notlar (DB sifresi, bilinen bug, karar) tekrar
# kesfedilsin. init.md'deki eski inline "Learnings on arama" akisinin yerini alir.
#
# Sessiz calisir: Obsidian Folder yoksa veya CLAUDE.local.md yoksa hicbir sey
# enjekte etmez (bos cikis). Asiri tetiklemeyi onlemek icin trivial prompt'lari
# (cok kisa / selamlasma) atlar.

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
  OBSIDIAN_FOLDER=$(grep "Obsidian Folder" "$CWD/CLAUDE.local.md" 2>/dev/null \
    | grep -v "^>" | grep -v "init-check" | head -1 \
    | sed -E 's/.*Obsidian Folder[*]*:[[:space:]]*//;s/[*]*[[:space:]]*$//')
fi
[ -n "$OBSIDIAN_FOLDER" ] || exit 0

# Trivial prompt'larda enjekte etme — cok kisa istekler (selamlasma, "evet", "ok",
# tek kelime) icin gereksiz. ~15 karakter alti atla.
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ "${#PROMPT}" -ge 15 ] || exit 0

HINT="Bu projenin Obsidian vault klasoru var: \`${OBSIDIAN_FOLDER}\`. Eger bu istek icin bir arastirma/inceleme yapilacaksa, ONCE \`obsidian-searcher\` agent'ini (run_in_background: true) cagirip vault'a bak — daha once benzer durumlar yasanmis, ogrenilen bilgiler ve elde edilen sonuclar (bilinen bug, DB/credential, mimari karar, calisan komut, cozum prosedurleri) kayitli olabilir. Arastirma yapmaktan cekinme; gecmis kayit cogu zaman sifirdan ugrasmaktan hizli ve dogru sonuc verir. Bulgu varsa baglam olarak kullan. Sadece selamlasma/trivial isteklerde arama yapma."

jq -n --arg ctx "$HINT" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
exit 0
