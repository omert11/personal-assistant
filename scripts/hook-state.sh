#!/bin/bash
# Ortak hook state tablosu yardimcisi — Stop hook'larinin oturum basina seyreltilmesi icin.
#
# State dosyasi: $CLAUDE_PLUGIN_DATA/hook-state.tsv (yoksa ~/.claude/plugins/data/... fallback)
# Satir formati (TAB ayrac):
#   session_id <TAB> session_start <TAB> last_daily_hook <TAB> last_learning_hook
#   - session_start      : oturumun ilk goruldugu epoch (saniye); satir olusunca yazilir
#   - last_daily_hook    : daily ozet hook'unun son calistigi epoch, 0 = hic
#   - last_learning_hook : learning hatirlatma hook'unun son calistigi epoch, 0 = hic
#
# Kullanim (source edilir):
#   source hook-state.sh
#   hook_state_touch_session "$SESSION_ID"                       # satir yoksa session_start ile olustur
#   ts=$(hook_state_get "$SESSION_ID" last_daily_hook)           # deger oku (yoksa 0)
#   hook_state_set "$SESSION_ID" last_daily_hook "$(date +%s)"   # deger yaz
#
# Tablo saf awk ile yazilir — jq/sqlite bagimliligi yok. Eszamanli yazimda
# kayip olabilir ama Stop hook'lari seri tetiklendigi icin pratikte sorun degil.

# State dosyasinin tam yolunu cozer (dizin yoksa olusturur).
_hook_state_file() {
  local data_dir="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/personal-assistant-personal-assistant}"
  mkdir -p "$data_dir" 2>/dev/null
  printf '%s/hook-state.tsv' "$data_dir"
}

# Atomik kilit (mkdir — flock'a gerek yok, macOS+Linux uyumlu). İki Stop hook'u
# ayni Stop event'inde ayni TSV'ye yazdiginda lost-update'i onler. Kilit en fazla
# ~1s beklenir; alinamazsa yine de devam edilir (best-effort, deadlock olmasin).
_hook_state_lock() {
  local lock i
  lock="$(_hook_state_file).lock"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if mkdir "$lock" 2>/dev/null; then
      return 0
    fi
    sleep 0.1 2>/dev/null || sleep 1
  done
  return 0
}
_hook_state_unlock() {
  rmdir "$(_hook_state_file).lock" 2>/dev/null
}

# Kolon adini 1-tabanli alan numarasina cevirir.
_hook_state_col() {
  case "$1" in
    session_start)      echo 2 ;;
    last_daily_hook)    echo 3 ;;
    last_learning_hook) echo 4 ;;
    *)                  echo 0 ;;
  esac
}

# hook_state_get <session_id> <column>  -> deger (yoksa 0)
hook_state_get() {
  local sid="$1" col_name="$2"
  local file col
  file=$(_hook_state_file)
  col=$(_hook_state_col "$col_name")
  [ "$col" -eq 0 ] && { echo 0; return; }
  [ -f "$file" ] || { echo 0; return; }
  awk -F'\t' -v sid="$sid" -v c="$col" '
    $1 == sid { print ($c == "" ? 0 : $c); found=1; exit }
    END { if (!found) print 0 }
  ' "$file"
}

# hook_state_set <session_id> <column> <value>
# Satir varsa ilgili kolonu gunceller, yoksa yeni satir ekler (eksik kolonlar 0).
hook_state_set() {
  local sid="$1" col_name="$2" val="$3"
  local file col tmp
  file=$(_hook_state_file)
  col=$(_hook_state_col "$col_name")
  [ "$col" -eq 0 ] && return 1

  touch "$file" 2>/dev/null || return 1
  tmp="${file}.tmp.$$"

  _hook_state_lock
  awk -F'\t' -v OFS='\t' -v sid="$sid" -v c="$col" -v val="$val" '
    $1 == sid {
      # Eksik kolonlari 0 ile doldur (4 kolonluk satir garanti et)
      if (NF < 4) { for (i = NF + 1; i <= 4; i++) $i = 0 }
      $c = val
      print
      found = 1
      next
    }
    { print }
    END {
      if (!found) {
        for (i = 2; i <= 4; i++) row[i] = 0
        row[c] = val
        print sid, row[2], row[3], row[4]
      }
    }
  ' "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  _hook_state_unlock
}

# Tablodaki session_start'i HOOK_STATE_TTL saniyeden eski olan satirlari siler.
# touch_session icinde cagrilir — tablo siskinligini onler.
HOOK_STATE_TTL="${HOOK_STATE_TTL:-604800}"  # 7 gun (saniye)
_hook_state_prune() {
  local file now tmp
  file=$(_hook_state_file)
  [ -f "$file" ] || return 0
  now=$(date +%s)
  # Once SADECE budanacak satir var mi diye bak (rewrite yapmadan). Yoksa cik —
  # her touch'ta tam dosya rewrite'ini onler (TTL 7 gun, nadiren tetiklenir).
  awk -F'\t' -v now="$now" -v ttl="$HOOK_STATE_TTL" '
    { start = ($2 == "" ? 0 : $2); if (start != 0 && (now - start) > ttl) { print "stale"; exit } }
  ' "$file" 2>/dev/null | grep -q stale || return 0

  tmp="${file}.tmp.$$"
  _hook_state_lock
  awk -F'\t' -v now="$now" -v ttl="$HOOK_STATE_TTL" '
    {
      start = ($2 == "" ? 0 : $2)
      # session_start 0 ise (eski/bozuk satir) veya TTL icindeyse koru
      if (start == 0 || (now - start) <= ttl) print
    }
  ' "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  _hook_state_unlock
}

# hook_state_touch_session <session_id>
# Once eski satirlari budar, sonra oturum satiri yoksa session_start = simdiki
# epoch ile olusturur. Satir zaten varsa session_start'a DOKUNMAZ (ilk gorulen
# zaman korunur).
hook_state_touch_session() {
  local sid="$1"
  local existing
  _hook_state_prune
  existing=$(hook_state_get "$sid" session_start)
  if [ "$existing" = "0" ]; then
    hook_state_set "$sid" session_start "$(date +%s)"
  fi
}

# hook_obsidian_folder <claude_local_md_path>
# CLAUDE.local.md'den Obsidian klasor adini cikarir. Desteklenen formatlar:
#   - "- **Obsidian Folder**: x"           (bitisik, personal-assistant)
#   - "Obsidian Folder: x"                  (duz)
#   - "| **Obsidian** | Folder: `x` |"      (markdown tablo, b2b-dmc)
# "Obsidian" ve "Folder" ayni satirda (aralarinda ** | gibi seyler olabilir).
# Dokumantasyon/aciklama satirlarini (">", "init-check" iceren) eler. Deger
# etrafindaki backtick/**/pipe/bosluk temizlenir. \K / \s GNU/Perl regex'i macOS
# BSD grep'te calismaz — tasinabilir grep+sed. Bu mantik 4 hook'ta ortak.
hook_obsidian_folder() {
  local file="$1" line val
  [ -f "$file" ] || return 0
  # Sadece "Obsidian ... Folder ... :" iceren (KOLON zorunlu) satirlari al — kolonsuz
  # prose/baslik satirlari ("## Obsidian Folder", "The Obsidian Folder is used")
  # deger TASIMAZ, eslenmez. Girintili blockquote dahil ">" ile baslayan aciklama
  # satirlarini ele (basta opsiyonel bosluk). init-check aciklamasini da ele.
  line=$(grep -E "Obsidian.*Folder[^:]*:" "$file" 2>/dev/null \
    | grep -vE "^[[:space:]]*>" \
    | grep -v "init-check" \
    | head -1)
  [ -n "$line" ] || return 0
  # Kolon SONRASI degeri al; backtick/**/pipe/bosluk temizle. Deger bos kalirsa
  # (kolon var ama sagi bos: "Obsidian Folder:") bos doner — MALFORMED tetikler.
  val=$(printf '%s' "$line" \
    | sed -E 's/.*Folder[^:]*:[[:space:]]*//; s/^[`*[:space:]]*//; s/[`*|[:space:]]*$//')
  # Placeholder degerleri (<isim>, <name> gibi) gercek deger sayma.
  case "$val" in
    "<"*">"|"") return 0 ;;
  esac
  printf '%s\n' "$val"
}
