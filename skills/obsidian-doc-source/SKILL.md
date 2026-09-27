---
name: obsidian-doc-source
description: Dış kaynağı (URL/library/PDF/repo) global Obsidian docs/ altına sectioned dokümante eder.
when_to_use: Trigger — "bu kaynağı dokümante et", "obsidian docs'a ekle", "API'yi dokümante et", "kütüphaneyi kaydet", "/obsidian-doc-source <kaynak>". Çıktı `~/Documents/ObsidianVault/docs/<source>/` (proje bağımsız).
argument-hint: <url-veya-library-veya-dosya>
allowed-tools: Skill, Read, Write, Edit, Bash, Glob, Grep, WebFetch, AskUserQuestion
---

# Obsidian Doc Source

Hedef: `~/Documents/ObsidianVault/docs/<source-name>/` (global, proje klasörü değil).

## Kurallar

- Dosyaları ana agent kendisi yazar; subagent'a devretme. (`/crawl2md` yalnız fetch aracıdır; çıktısını ana agent okur.)
- Kaynağın teknik yapısını aktar: endpoint, parametre, tip, default, dönüş, hata kodu, limit, kod örneği.
- Yorum/değerlendirme yazma ("oldukça esnek", "dikkat edilmesi gereken" vb.); kaynakta yoksa satır yok.
- Yeniden ifade, iki bölümde tekrar, dolgu paragraf yasak.
- Kaynakta olmayan endpoint/parametre/örnek uydurma; kaynakta olmayan bölümün dosyası oluşturulmaz.
- Tablo tabloya, kod bloğu kod bloğuna; prose'a düzleştirme.
- Library için güncel dokümanı çek; kendi belleğinden yazma.
- UTF-8 + Türkçe karakter; kod blokları ve API isimleri İngilizce.
- Commit etme; yalnız vault'a yaz.

## Akış

### 1) Kaynak

`$ARGUMENTS` yoksa soru aracıyla sor (header: "Kaynak", question: "Hangi kaynağı dokümante edeyim?", options: ["Web URL", "Library/npm", "Local dosya", "GitHub repo"]).

Örnekler:

```
/obsidian-doc-source https://developers.google.com/maps/documentation/places/web-service
/obsidian-doc-source stripe-node
/obsidian-doc-source ~/Downloads/api-spec.pdf
/obsidian-doc-source https://github.com/anthropics/claude-code
```

### 2) Tip Tespiti

| Pattern | Tip | Fetch |
|---|---|---|
| `http(s)://github.com/<owner>/<repo>` | GitHub | `gh api repos/<owner>/<repo>/readme` + contents/docs |
| `http(s)://` (tek sayfa / küçük docs) | Web | Sayfayı çek (default) |
| `http(s)://` (multi-page docs sitesi) | Web (crawl) | `/crawl2md` |
| Çıplak isim (`react`, `stripe-node`) | Library | Güncel library dokümanını çek |
| `.pdf` / `.docx` / `.html` / `.epub` local | Binary | Markdown'a çevir |
| `.md` local | Markdown | Doğrudan oku |

Belirsizse soru aracıyla sor (header: "Tip", options: listeden).

Web'de tek sayfa fetch'ten `/crawl2md`'ye eskale koşulları: kullanıcı "siteyi komple" der; ilk fetch'te `/docs/` + çok nav link (multi-section) görülür; fetch cevabı başka sayfalara işaret eder. Eskalasyonda soru aracıyla sor (header: "Fetch", question: "Bu docs sitesi multi-page görünüyor. Crawl edeyim mi?", options: ["Tek sayfa yeter", "Tam crawl (crawl2md)"]).

```
OUT_DIR=$(mktemp -d -t obsidian-doc-source-XXXXXX)
Skill(skill: "personal-assistant:crawl2md", args: "<URL> $OUT_DIR --depth 2 --delay 0.5")
```

### 3) Kaynak Adı ve Çakışma

- Library: paket adı kebab-case (`@stripe/stripe-node` → `stripe-node`)
- URL: domain + path son segmenti (`https://api.stripe.com/docs/api` → `stripe-api`)
- GitHub: `<owner>-<repo>`
- Dosya: uzantısız filename, kebab-case

```bash
ls ~/Documents/ObsidianVault/docs/<source-name> 2>/dev/null
```

Varsa eski `fetched_at`'i `docs/<source-name>/index.md` frontmatter'ından oku (varsa) ve soru aracıyla sor:
- header: "Çakışma"
- question: "`docs/<source-name>/` zaten var (son güncelleme: `<fetched_at>`). Ne yapayım?"
- options:
  - "Üstüne yaz" — adım 6'da silinip yeniden yazılır
  - "Yeni sürüm" — `docs/<source-name>-v<N+1>/` (N = eski sürüm sayısı)
  - "İptal" — çık

### 4) Tamamını Oku

Kısmi özet yasak; her sayfa/dosya okunur.

- Web (tek sayfa): "next page"/pagination linklerini follow-up çağrılarla takip et.
- crawl2md: `<OUT_DIR>` altındaki tüm `.md` dosyalarını tek mesajda paralel oku.
- GitHub: README + `docs/` altındaki tüm `.md`, `gh api` ile.
- Library: library ID'yi bul; en az 3 query (overview, API reference, examples) ile dokümanı çek.
- Local file: markdown'a çevrilmiş çıktının tamamını oku, parçalama.

Sınırlar:
- crawl2md >50 markdown → soru aracıyla sor (header: "Kapsam", options: ["İlk 50 dosya (depth azalt)", "Sadece index/toc sayfaları", "Custom glob", "Tamamı — büyük olabilir"]).
- >200 sayfa → soru aracıyla birden fazla source'a split öner (`stripe-api-core`, `stripe-api-webhooks`).
- Context zorlanıyorsa bölüm bölüm: bölüm kaynağını oku → `{section}.md`'yi hemen yaz → sıradaki.

### 5) Bölümleme

Kaynakta karşılığı olmayan bölüm atlanır (dosya yok, sub-MOC'ta yok).

| Section | Dosya | Başlık | İçerik |
|---|---|---|---|
| overview | `overview.md` | Overview | Ne olduğu + kullanım alanı + key features; kaynaktaki tanım, ≤2-3 paragraf |
| auth | `auth.md` | Authentication | Auth tipi, flow adımları, örnek header/token |
| endpoints | `endpoints.md` | Endpoints | Her endpoint: method + path + açıklama + params tablosu + response example |
| examples | `examples.md` | Examples | Kaynaktaki çalışır kod blokları (curl + en az 1 dil) |
| reference | `reference.md` | Reference | Tüm parametreler: isim, tip, default, açıklama — tablo |
| errors | `errors.md` | Errors | HTTP status + error code + anlamı + çözüm — tablo |
| rate_limits | `rate_limits.md` | Rate Limits | Limit değerleri, window, header isimleri, aşım davranışı |
| sdk | `sdk.md` | SDK / Clients | Resmi SDK: dil + paket adı + repo link |
| changelog | `changelog.md` | Changelog | Son 3-5 sürüm notu, breaking changes vurgulu |

Temizlik: nav/footer/cookie banner kalıntısını sil, tekrarlanan başlıkları birleştir, kod bloğu dil etiketini düzelt (```python, ```bash, ```json), kırık tabloyu onar, placeholder linkleri (`[click here]()`) kaldır.

### 6) Yaz

1. "Üstüne yaz" seçildiyse tam yolla sil (değişken/placeholder ile `rm -rf` çalıştırma): `rm -rf ~/Documents/ObsidianVault/docs/<source-name>`
2. `mkdir -p <TARGET>`
3. Dolu her bölüm için `<TARGET>/<section>.md`; yazımlar tek mesajda batch.
4. `<TARGET>/index.md` (sub-MOC): yalnız dolu bölümlerin wikilink'i.
5. `~/Documents/ObsidianVault/docs/index.md`: yoksa oluştur; varsa "Kaynaklar" bölümüne `[[<source-name>/index|<source-name>]]` ekle (aynı link varsa dokunma).

`<TARGET>/<section>.md`:

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

{bölüm içeriği}

## İlgili

- [[index|{SOURCE_NAME}]]
- [[../index|Global Docs MOC]]
```

`<TARGET>/index.md` (`## Kaynak ve Edinim` zorunlu; karşılığı olmayan maddeyi çıkar):

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

- **Birincil kaynak**: {kaynak + edinim yöntemi: library ID + sorgu sayısı / OpenAPI export / mail eki + dönüştürme / tek sayfa fetch / crawl2md}
- **İlgili referans**: {Plane issue (PROJ-N) / mail konu-ID + varsa orijinal dosya yolu}
- **Credential'lar**: [[<credential-learnings-notu>]]
- **Doğrulama**: {✅/❌ + tarih + kısa sonuç, örn. "CreateTokenV2 ✅ 2026-06-11, token alındı"}

## Bölümler

- [[overview]] — Overview
- [[endpoints]] — Endpoints
- ...

## İlgili

- [[../index|Global Docs MOC]]
```

`~/Documents/ObsidianVault/docs/index.md` (yoksa):

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

### 7) Temizlik

crawl2md kullanıldıysa: `rm -rf "$OUT_DIR"`

### 8) Rapor

Yazılan dosya path listesi; atlanan bölümler tek satırda (hangisi, neden: kaynakta yok).

## Hata Yönetimi

| Hata | Aksiyon |
|---|---|
| `~/Documents/ObsidianVault/` yok | Kullanıcıya bildir, iptal |
| Fetch 4xx/5xx | Rapor et, URL doğrula, iptal |
| Library dokümanı boş sonuç | Soru aracıyla sor (header: "Fallback", options: ["URL gir", "İptal"]) |
| Doküman markdown'a çevrilemiyor | Rapor et, iptal |
| gh unauthenticated | `gh auth login` öner, iptal |
| crawl2md fail | Geçici dizini sil, hatayı raporla |
