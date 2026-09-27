---
name: crawl2md
description: Web sitesini markdown'a crawl eder + web-scrape-cleaner ile temizler.
when_to_use: Trigger — "siteyi crawl et", "URL'i markdown yap", "web scrape et", "siteyi indir markdown'a çevir", "/crawl2md <url> <dir>". Iki aşama (ham scrape + temizleme), her aşamada onay sorar.
argument-hint: <URL> <OUT_DIR> [--depth N] [--delay S] [--include-binary]
disable-model-invocation: false
allowed-tools: Bash, Read, Glob, Grep, Task
---

# Crawl2md

## Girdi

`$ARGUMENTS` → `$0` URL, `$1` OUT_DIR, `$2+` flags (`--depth N`, `--delay S`, `--include-binary`).
`$0` veya `$1` boşsa soru aracıyla sor.

## Akış

### 1. Ön Kontrol

Script: `${CLAUDE_SKILL_DIR}/scripts/crawl2md.py` (shebang `uv run --script`, PEP 723; `markitdown[all]` ephemeral venv'e otomatik gelir — global `markitdown` kurma). Tek dep `uv`; yoksa `brew install uv` öner.

```bash
which uv || echo "uv kurulu degil — brew install uv"
ls "${CLAUDE_SKILL_DIR}/scripts/crawl2md.py" || echo "script bulunamadi"
```

### 2. Crawl Parametreleri

Eksik/belirsizse soru aracıyla sor:
- header: "Crawl params"
- question: "Depth, delay, binary?"
- options: ["Default (depth=3, delay=0.5)", "Deep (depth=5)", "Hızlı (depth=2, delay=0)", "Custom"]

`--delay 0` seçilirse rate-limit riski için uyar.

### 3. Onay

Soru aracıyla sor:
- header: "Crawl başlat"
- question: "$0 → $1 crawl edilecek. Başla?"
- options: ["Başla", "Önce boyut tahmini", "İptal"]

>500 dosya tahmin ediliyorsa ayrıca onay al, depth azaltmayı öner.

### 4. Crawl Çalıştır

```bash
"${CLAUDE_SKILL_DIR}/scripts/crawl2md.py" $ARGUMENTS
```

Script yalnız aynı host'taki linkleri izler.

### 5. Rapor

- Yazılan dosya sayısı (script çıktısından)
- Toplam boyut (`du -sh $OUT_DIR`)
- Örnek 3 dosya yolu

### 6. Temizleme Onayı

Soru aracıyla sor:
- header: "Temizleme"
- question: "$1'deki N dosya `web-scrape-cleaner` agent ile temizlensin mi?"
- options:
  - "Evet, aggressive (Recommended)" — Nav/footer/cookie/reklam blokları + boş başlık + link gürültüsü silinir
  - "Evet, conservative" — Sadece boş satır + script kalıntısı
  - "Hayır, ham bırak"

Cleaner dosyaların üstüne yazar; kullanıcı yedek isterse önce `cp -r $1 $1.original/`.

### 7. Cleaner Agent

Evet seçildiyse `web-scrape-cleaner` agent'ını (`agents/web-scrape-cleaner.md`) sub-agent olarak başlat:

```
TARGET: $1
MODE: aggressive | conservative
KEEP: (kullanıcı istisna verirse)
```

### 8. Son Durum

Agent raporunu özetle: dosyalar $1'de (ham veya temizlenmiş, üstüne yazılmış), toplam silinen satır, düzenlenen dosya sayısı.
