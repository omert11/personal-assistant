#!/bin/bash
# Init Check Script — Cross-platform basic checks
# Dosya varlik + yapilandirma kontrolu yapar

MISSING=()
MALFORMED=()
PROJECT_NAME=$(basename "$PWD")

# Ortak extraction helper'i (hook_obsidian_folder vb.) — varsa yukle ki format
# dogrulamasi hook'lardaki ile AYNI mantikla yapilsin.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
[ -f "$SCRIPT_DIR/hook-state.sh" ] && . "$SCRIPT_DIR/hook-state.sh" 2>/dev/null

# CLAUDE.md kontrolu
[ ! -f "CLAUDE.md" ] && MISSING+=("CLAUDE.md")

# CLAUDE.local.md kontrolu
#
# UYARI — FORMAT: Anahtar kelimeler ("Obsidian Folder", "Vikunja", "Solo") farkli
# yazim bicimlerinde tanimlanabilir; bu yuzden BITISIK string ("Obsidian Folder")
# yerine ESNEK pattern ("Obsidian.*Folder") kullanilir. Desteklenen formatlar:
#   - "- **Obsidian Folder**: x"           (bitisik, personal-assistant)
#   - "| **Obsidian** | Folder: `x` |"      (markdown tablo, b2b-dmc)
# Bitisik grep tablo formatini KACIRIR ve yanlis "eksik" uyarisi verir (b2b-dmc
# bug'i). Bu kontrol scripts/hook-state.sh:hook_obsidian_folder() ile AYNI
# format mantigini kullanmali — yeni bir format eklenirse iki yeri de guncelle.
if [ ! -f "CLAUDE.local.md" ]; then
  MISSING+=("CLAUDE.local.md")
else
  grep -q "Vikunja" CLAUDE.local.md 2>/dev/null || MISSING+=("Vikunja ID")
  grep -q "Solo" CLAUDE.local.md 2>/dev/null || MISSING+=("Solo ID")

  # Obsidian Folder: once VAR MI, sonra FORMAT DOGRU MU (deger cikarilabiliyor mu).
  # Satir var ama deger bos cikiyorsa format yanlis (orn. beklenmeyen bir yazim) —
  # bu sessiz bir tuzak: hook'lar OBSIDIAN_FOLDER bos olunca sessizce skip eder,
  # daily/searcher/remind hic calismaz. Bunu MALFORMED olarak ayri raporla.
  if grep -q "Obsidian.*Folder" CLAUDE.local.md 2>/dev/null; then
    if command -v hook_obsidian_folder >/dev/null 2>&1; then
      _of=$(hook_obsidian_folder "CLAUDE.local.md")
      [ -n "$_of" ] || MALFORMED+=("Obsidian Folder (satir var ama deger okunamadi — format hatali)")
    fi
  else
    MISSING+=("Obsidian Folder")
  fi
fi

# Sonuc — oncelik: eksik > format-hatali > OK
if [ ${#MISSING[@]} -gt 0 ]; then
  IFS=','; echo "INIT_MISSING|$PROJECT_NAME|${MISSING[*]}"
elif [ ${#MALFORMED[@]} -gt 0 ]; then
  IFS=','; echo "INIT_MALFORMED|$PROJECT_NAME|${MALFORMED[*]}"
else
  echo "INIT_OK|$PROJECT_NAME"
fi
