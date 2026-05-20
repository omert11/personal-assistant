---
name: crawl2md
description: Web sitesini markdown'a crawl eder + web-scrape-cleaner ile temizler.
when_to_use: Trigger — "siteyi crawl et", "URL'i markdown yap", "web scrape et", "siteyi indir markdown'a çevir", "/crawl2md <url> <dir>". Iki aşama (ham scrape + temizleme), her aşamada onay sorar.
argument-hint: <URL> <OUT_DIR> [--depth N] [--delay S] [--include-binary]
disable-model-invocation: false
allowed-tools: Bash, Read, Glob, Grep, Task
---

# Crawl2md

Web sitesini recursive olarak crawl'lar, HTML/PDF/Office içeriği markdown'a çevirir, sonra `web-scrape-cleaner` agent ile temizler.

## Girdi

`$ARGUMENTS` → `<URL> <OUT_DIR> [crawl2md flagleri]`

- `$0` → URL
- `$1` → OUT_DIR
- `$2+` → flags

Örnekler:
- `/crawl2md https://docs.example.com ./scraped`
- `/crawl2md https://example.com ./out --depth 2 --delay 1.0`
- `/crawl2md https://example.com ./out --include-binary`

`$0` veya `$1` boşsa: `AskUserQuestion` ile URL ve OUT_DIR sor.

## Akış

### 1. Ön Kontrol

Script skill bundle içinde — `${CLAUDE_SKILL_DIR}/scripts/crawl2md.py`. Çalıştırma için `uv` yeterli (PEP 723 inline deps), `markitdown` ek kurulum gerekmez (script kendisi ephemeral venv'e çeker).

```bash
which uv || echo "uv kurulu degil — brew install uv"
ls "${CLAUDE_SKILL_DIR}/scripts/crawl2md.py" || echo "script bulunamadi"
```

`uv` yoksa `brew install uv` öner. Başka dep yok.

### 2. Crawl Parametreleri

`$ARGUMENTS` parse et. Eksik/belirsizse `AskUserQuestion`:
- header: "Crawl params"
- question: "Depth, delay, binary?"
- options: ["Default (depth=3, delay=0.5)", "Deep (depth=5)", "Hızlı (depth=2, delay=0)", "Custom"]

### 3. Onay

`AskUserQuestion`:
- header: "Crawl başlat"
- question: "$0 → $1 crawl edilecek. Başla?"
- options: ["Başla", "Önce boyut tahmini", "İptal"]

### 4. Crawl Çalıştır

```bash
"${CLAUDE_SKILL_DIR}/scripts/crawl2md.py" $ARGUMENTS
```

Script shebang `uv run --script` — uv otomatik ephemeral venv'de `markitdown[all]` resolve eder (ilk çalıştırmada indirir, sonra cache). Ayrıca global `markitdown` kurulumu gerekmez.

Çıktıdan yazılan dosya sayısını topla.

### 5. Rapor

Crawl bitince:
- Yazılan dosya sayısı
- Toplam boyut (`du -sh $OUT_DIR`)
- Örnek 3 dosya yolu

### 6. Temizleme Onayı

`AskUserQuestion`:
- header: "Temizleme"
- question: "$1'deki N dosya `web-scrape-cleaner` agent ile temizlensin mi?"
- options:
  - "Evet, aggressive (Recommended)" — Nav/footer/cookie/reklam blokları + boş başlık + link gürültüsü silinir
  - "Evet, conservative" — Sadece boş satır + script kalıntısı
  - "Hayır, ham bırak"

### 7. Cleaner Agent Çağır

Evet seçildiyse `Task` ile `web-scrape-cleaner` agent'ını başlat:

```
TARGET: $1
MODE: aggressive | conservative
KEEP: (kullanıcı istisna verirse)
```

Agent raporunu kullanıcıya özetle sun.

### 8. Son Durum

- Ham dosya: $1 (temizlenmedi seçildiyse)
- Temizlenmiş dosya: $1 (üstüne yazıldı)
- Raporda: toplam silinen satır, düzenlenen dosya sayısı

## Kritik Kurallar

- **Same-host kilidi**: crawl2md.py zaten sadece aynı hosttaki link'leri izler (başka siteye sızmaz)
- **Delay zorunlu**: Default 0.5s, agresif kullanıcı `--delay 0` yazabilir ama rate-limit riski var — uyar
- **Büyük siteler**: >500 dosya tahmin ediliyorsa `AskUserQuestion` ile onay al (depth azaltma öner)
- **Cleaner yedek**: web-scrape-cleaner aggressive modda orijinali üstüne yazar. Kullanıcı istiyorsa önce `cp -r $1 $1.original/` yap

## İlgili Dosyalar

- `${CLAUDE_SKILL_DIR}/scripts/crawl2md.py` — crawl + markitdown script (uv PEP 723, skill bundle içinde)
- `agents/web-scrape-cleaner.md` — temizleme agent'ı (plugin root'unda, Task tool ile çağrılır)
- `rules/cli-tools.md` — markitdown komutları (referans)
