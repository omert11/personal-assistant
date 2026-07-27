---
name: obsidian-doc-source
description: Dış kaynağı (URL/library/PDF/repo) global Obsidian docs/ altına sectioned dokümante eder.
when_to_use: Trigger — "bu kaynağı dokümante et", "obsidian docs'a ekle", "API'yi dokümante et", "kütüphaneyi kaydet", "/obsidian-doc-source <kaynak>". WebFetch/ctx7/markitdown/gh kullanır; çıktı `~/Documents/ObsidianVault/docs/<source>/` (proje bağımsız).
argument-hint: <url-veya-library-veya-dosya>
allowed-tools: Skill, Read, Write, Edit, Bash, Glob, Grep, WebFetch, AskUserQuestion
---

# Obsidian Doc Source

Dış kaynağı profesyonel sectioned API reference olarak **global docs klasörüne** (`~/Documents/ObsidianVault/docs/<source>/`) dokümante eder. Proje folder'ı altında DEĞİL — tüm projeler aynı docs pool'unu paylaşır.

## Yazma Modeli — Ana Agent Yazar, Delege YOK

Dosyaları **ana agent kendisi yazar** (`Write`/`Edit` ile). Bu skill hiçbir subagent'a devretmez.

**Sebep**: dokümanı okuyan agent ile yazan agent aynı olmalı. Devirde içerik prompt'a serialize edilir, teknik detay (parametre tipi, default değer, error code, kod bloğu) yolda kayar; devralan agent kaynağı görmediği için kaybı fark edemez. Ana agent kaynağı ham haliyle context'inde tutar, doğrudan dosyaya yazar — kayıp yok.

**Yazım disiplini (ZORUNLU)**:
- **Kaynağın teknik yapısını aktar** — endpoint, parametre, tip, default, dönüş, hata kodu, limit değeri, kod örneği. Ne varsa o.
- **Yorum yapma** — "bu API oldukça esnek", "dikkat edilmesi gereken nokta", "pratikte genelde" gibi cümleler yazma. Kaynakta yoksa satır yok.
- **Uzatma** — açıklamayı yeniden ifade etme, aynı bilgiyi iki bölümde tekrarlama, dolgu paragraf yazma yasak.
- **Uydurma yasak** — kaynakta olmayan endpoint/parametre/örnek yazma. Bölüm kaynakta yoksa o dosya hiç oluşturulmaz.
- Tablo tabloya, kod bloğu kod bloğuna çevrilir. Prose'a düzleştirme.

## Önkoşul

- Vault kök: `~/Documents/ObsidianVault/` mevcut
- Global docs klasörü `mkdir -p` ile oluşturulur

## Akış

### 1) Kaynağı Al

`$ARGUMENTS` kaynak olarak gelir. Yoksa `AskUserQuestion` ile sor (header: "Kaynak", question: "Hangi kaynağı dokümante edeyim?", options: ["Web URL", "Library/npm", "Local dosya", "GitHub repo"]).

### 2) Kaynak Tipini Tespit Et (Router)

| Pattern | Tip | Fetch |
|---|---|---|
| `http(s)://github.com/<owner>/<repo>` | GitHub | `gh api repos/<owner>/<repo>/readme` + contents/docs |
| `http(s)://` (tek sayfa veya küçük docs) | Web | `WebFetch` (default) |
| `http(s)://` (multi-page docs sitesi) | Web (crawl) | `/crawl2md` delege |
| Çıplak isim (`react`, `stripe-node`) | Library | `ctx7` CLI |
| `.pdf` / `.docx` / `.html` / `.epub` local | Binary | `markitdown <file>` (rules/cli-tools.md ref) |
| `.md` local | Markdown | `Read` |

Belirsizse `AskUserQuestion` (header: "Tip", options: listeden).

> `/crawl2md` bir **fetch aracıdır** (ham markdown üretir), yazma devri değil. Çıktısını ana agent okur.

#### Web URL: Fetch Stratejisi

**Default: WebFetch** (tek sayfa, 1 çağrı). Şu durumlarda `/crawl2md`'ye eskale et:
- Kullanıcı explicit "siteyi komple" ister
- URL path'inde `/docs/` + multi-section olduğunu ilk WebFetch'te gör (many nav links)
- WebFetch cevabı "bu sayfa başka sayfalara işaret ediyor" bilgisi verir

Eskale kararında `AskUserQuestion` (header: "Fetch", question: "Bu docs sitesi multi-page görünüyor. Crawl edeyim mi?", options: ["Tek sayfa yeter (WebFetch)", "Tam crawl (crawl2md)"]).

Crawl2md delegasyonu:
```
OUT_DIR=$(mktemp -d -t obsidian-doc-source-XXXXXX)
Skill(skill: "personal-assistant:crawl2md", args: "<URL> $OUT_DIR --depth 2 --delay 0.5")
```

Crawl2md kendi içinde web-scrape-cleaner'ı onayla çalıştırır.

### 3) Kaynak Adı Üret ve Çakışma Kontrolü

Kaynak adı kuralları:
- Library: paket adı kebab-case (`@stripe/stripe-node` → `stripe-node`)
- URL: domain + path son segmenti (`https://api.stripe.com/docs/api` → `stripe-api`)
- GitHub: `<owner>-<repo>`
- Dosya: filename (uzantısız, kebab-case)

Target path: `~/Documents/ObsidianVault/docs/<source-name>/`

**Çakışma kontrolü:**

```bash
ls ~/Documents/ObsidianVault/docs/<source-name> 2>/dev/null
```

Varsa `AskUserQuestion`:
- header: "Çakışma"
- question: "`docs/<source-name>/` zaten var (son güncelleme: `<fetched_at>`). Ne yapayım?"
- options:
  - "Üstüne yaz" — `rm -rf ~/Documents/ObsidianVault/docs/<source-name>` sonra yeniden yazılır (yol tam yazılır; değişken/placeholder ile `rm -rf` çalıştırma)
  - "Yeni sürüm" — `docs/<source-name>-v<N+1>/` olarak yaz (N eski sürüm sayısı)
  - "İptal" — skill çık

Eski `fetched_at` bilgisini `docs/<source-name>/index.md` frontmatter'ından oku (varsa).

### 4) Kaynağın Tamamını Oku

**Zorunlu:** Kaynağın tamamını işle — kısmi özet yasak. Her sayfa/dosya Read ile gezilir.

- **Web (WebFetch)**: Sayfa sonundaki "next page" / pagination link'lerini takip et. Tek WebFetch yetmiyorsa follow-up çağrıları yap
- **crawl2md çıktısı**: `Glob <OUT_DIR>/**/*.md` ile tüm dosyaları bul, hepsini Read et (paralel batch — tek mesajda çoklu Read tool call)
- **GitHub**: README + `docs/` klasörünün tüm `.md` dosyalarını `gh api` ile çek
- **Context7 (`ctx7` CLI)**: `npx ctx7@latest library <name> "<query>"` ile ID al, sonra `npx ctx7@latest docs <libraryId> "<query>"` çağrısını en az 3 farklı query ile yap (overview, API reference, examples) ki tüm doc coverage gelsin
- **Local file**: markitdown'un tam çıktısını Read et, parçalama

#### Bounded Extraction

- Crawl2md >50 markdown dosyası üretirse: `AskUserQuestion` (header: "Kapsam", options: ["İlk 50 dosya (depth azalt)", "Sadece index/toc sayfaları", "Custom glob", "Tamamı — büyük olabilir"])
- Kaynak çok büyükse (>200 sayfa): `AskUserQuestion` ile split öner — birden fazla source olarak kaydet (`stripe-api-core`, `stripe-api-webhooks`, vb.)
- Context bütçesi zorlanıyorsa **bölüm bölüm yaz**: bir bölümün kaynağını oku → o `{section}.md`'yi hemen `Write` et → sıradakine geç. Hepsini bellekte biriktirip sona bırakma.

### 5) Bölümleme

Okunan içeriği aşağıdaki bölümlere ayır. **Kaynakta karşılığı olmayan bölümü atla** — o dosya oluşturulmaz, sub-MOC'ta listelenmez.

| Section | Dosya | İçerik formatı |
|---|---|---|
| overview | `overview.md` | Ne olduğu + kullanım alanı + key features. Kaynaktaki tanım, 2-3 paragrafı geçme |
| auth | `auth.md` | Auth tipi, flow adımları, örnek header/token |
| endpoints | `endpoints.md` | Her endpoint: method + path + açıklama + params tablosu + response example |
| examples | `examples.md` | Kaynaktaki çalışır kod blokları (curl + en az 1 dil) |
| reference | `reference.md` | Tüm parametreler: isim, tip, default, açıklama — markdown table |
| errors | `errors.md` | HTTP status + error code + anlamı + çözüm — markdown table |
| rate_limits | `rate_limits.md` | Limit değerleri, window, header isimleri, aşım davranışı |
| sdk | `sdk.md` | Resmi SDK listesi: dil + paket adı + repo link |
| changelog | `changelog.md` | Son 3-5 sürüm notu, breaking changes vurgulu |

Temizlik: nav/footer/cookie banner kalıntısı sil, tekrarlanan başlıkları birleştir, kod bloğu dil etiketini düzelt (```python, ```bash, ```json), kırık tabloyu onar, placeholder link (`[click here]()`) kaldır.

Section başlık mapping: `overview` → `Overview`, `auth` → `Authentication`, `endpoints` → `Endpoints`, `examples` → `Examples`, `reference` → `Reference`, `errors` → `Errors`, `rate_limits` → `Rate Limits`, `sdk` → `SDK / Clients`, `changelog` → `Changelog`.

### 6) Dosyaları Yaz

Sıra:

1. **Çakışma kararını uygula** — "Üstüne yaz" seçildiyse hedefi tam yolla sil: `rm -rf ~/Documents/ObsidianVault/docs/<source-name>`
2. `mkdir -p <TARGET>`
3. Dolu her bölüm için `<TARGET>/<section>.md` — **Write çağrılarını tek mesajda batch'le**
4. `<TARGET>/index.md` (sub-MOC) — sadece dolu bölümlerin wikilink'i
5. Global docs MOC (`~/Documents/ObsidianVault/docs/index.md`) — yoksa oluştur, varsa "Kaynaklar" bölümüne duplicate kontrolüyle `[[<source-name>/index|<source-name>]]` ekle

#### `<TARGET>/<section>.md`

```markdown
---
aliases:
  - {SOURCE_NAME} {section}
tags:
  - docs
  - {SOURCE_TYPE}
  - {section}
source_url: {SOURCE_URL}
fetched_at: {FETCHED_AT}
---

# {Section Başlığı}

{bölüm içeriği — kaynağın teknik yapısı, yorumsuz}

## İlgili

- [[index|{SOURCE_NAME}]]
- [[../index|Global Docs MOC]]
```

#### `<TARGET>/index.md` (sub-MOC)

`## Kaynak ve Edinim` bölümü **zorunlu**: frontmatter'daki `source_url`/`fetched_at` tek başına yeterli değil, provenance görünür olmalı.

```markdown
---
aliases:
  - {SOURCE_NAME}
tags:
  - docs
  - {SOURCE_TYPE}
source_url: {SOURCE_URL}
fetched_at: {FETCHED_AT}
---

# {SOURCE_NAME}

Kaynak: `{SOURCE_URL}`
Çekildi: {FETCHED_AT}
Tip: {SOURCE_TYPE}

## Kaynak ve Edinim

- **Birincil kaynak**: {kaynak + edinim yöntemi: Context7 library ID + sorgu sayısı / OpenAPI export / mail eki + dönüştürme / WebFetch / crawl2md}
- **İlgili referans**: {Plane issue (PROJ-N) / mail konu-ID + varsa orijinal dosya yolu}
- **Credential'lar**: [[<credential-learnings-notu>]]
- **Doğrulama**: {✅/❌ + tarih + kısa sonuç, örn. "CreateTokenV2 ✅ 2026-06-11, token alındı"}

Karşılığı olmayan maddeyi yazma — satırı çıkar.

## Bölümler

- [[overview]] — Overview
- [[endpoints]] — Endpoints
- ...

## İlgili

- [[../index|Global Docs MOC]]
```

#### Global Docs MOC (`~/Documents/ObsidianVault/docs/index.md`)

Yoksa oluştur:

```markdown
---
aliases:
  - Global Docs
  - Docs MOC
tags:
  - docs
  - moc
---

# Global Docs

Tüm projeler arası paylaşılan kaynak dokümantasyonu. Her source `<source-name>/index.md` alt-MOC'una link'lenir.

## Kaynaklar

- [[stripe-api/index|stripe-api]]
- [[google-maps-places/index|google-maps-places]]
```

Varsa "Kaynaklar" bölümüne `Edit` ile ekle — aynı wikilink zaten varsa dokunma.

### 7) Geçici Dizin Temizliği

Crawl2md kullanıldıysa:
```bash
rm -rf "$OUT_DIR"
```

### 8) Rapor

Yazılan dosyaların path listesini ver. Atlanan bölüm varsa **hangisi ve neden** (kaynakta yok) tek satırda belirt.

## Argüman Örnekleri

```
/obsidian-doc-source https://developers.google.com/maps/documentation/places/web-service
/obsidian-doc-source stripe-node
/obsidian-doc-source ~/Downloads/api-spec.pdf
/obsidian-doc-source https://github.com/anthropics/claude-code
```

## Hata Yönetimi

| Hata | Aksiyon |
|---|---|
| WebFetch 4xx/5xx | Kullanıcıya rapor, URL doğrula, iptal |
| Context7 boş sonuç | `AskUserQuestion` (header: "Fallback", options: ["WebFetch URL gir", "İptal"]) |
| markitdown kurulu değil | `uv tool install 'markitdown[all]'` öner ve iptal |
| gh unauthenticated | `gh auth login` öner ve iptal |
| crawl2md fail | Geçici dizini sil, hatayı kullanıcıya rapor |
| Vault kök yok | `~/Documents/ObsidianVault/` bulunamadı — kullanıcıya bildir, iptal |

## Kurallar

- **Yazma devri yok** — dosyaları ana agent yazar, subagent'a devretme (bkz. Yazma Modeli)
- **Schema uydurma** — kaynakta olmayan endpoint/parametre yazma
- **Library için Context7 zorunlu** — kendi belleğinden React/Next.js yazma
- **Yorum/dolgu yasak** — kaynağın teknik yapısı aktarılır, değerlendirme eklenmez
- **UTF-8 + Türkçe karakter** (kod blokları ve API isimleri İngilizce)
- **Commit etme** — skill sadece vault'a yazar, git'e dokunmaz
