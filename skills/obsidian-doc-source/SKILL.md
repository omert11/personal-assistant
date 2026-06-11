---
name: obsidian-doc-source
description: Dış kaynağı (URL/library/PDF/repo) global Obsidian docs/ altına sectioned dokümante eder.
when_to_use: Trigger — "bu kaynağı dokümante et", "obsidian docs'a ekle", "API'yi dokümante et", "kütüphaneyi kaydet", "/obsidian-doc-source <kaynak>". WebFetch/ctx7/markitdown/gh kullanır; çıktı `~/Documents/ObsidianVault/docs/<source>/` (proje bağımsız).
argument-hint: <url-veya-library-veya-dosya>
allowed-tools: Task, Skill, Read, Write, Edit, Bash, Glob, Grep, WebFetch
---

# Obsidian Doc Source

Dış kaynağı profesyonel sectioned API reference olarak **global docs klasörüne** (`~/Documents/ObsidianVault/docs/<source>/`) dokümante eder. Proje folder'ı altında DEĞİL — tüm projeler aynı docs pool'unu paylaşır.

## Önkoşul

- Vault kök: `~/Documents/ObsidianVault/` mevcut
- Global docs klasörü writer agent tarafından `mkdir -p` ile oluşturulur

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

**Çakışma kontrolü (skill'de, writer'a gitmeden önce):**

```bash
ls ~/Documents/ObsidianVault/docs/<source-name> 2>/dev/null
```

Varsa `AskUserQuestion`:
- header: "Çakışma"
- question: "`docs/<source-name>/` zaten var (son güncelleme: `<fetched_at>`). Ne yapayım?"
- options:
  - "Üstüne yaz" — eski dosyalar silinir, yeniden yazılır
  - "Yeni sürüm" — `docs/<source-name>-v<N+1>/` olarak yaz (N eski sürüm sayısı)
  - "İptal" — skill çık

Eski `fetched_at` bilgisini `docs/<source-name>/index.md` frontmatter'ından oku (varsa).

### 4) Kaynağın Tamamını Oku, Düzenle, Formatla

**Zorunlu:** Kaynağın tamamını işle — kısmi özet yasak. Her sayfa/dosya Read ile gezilir, içerik birleştirilir, sonra profesyonel API reference formatına yeniden düzenlenir.

#### 4a) Tüm İçeriği Oku

- **Web (WebFetch)**: Sayfa sonundaki "next page" / pagination link'lerini takip et. Tek WebFetch yetmiyorsa follow-up çağrıları yap
- **crawl2md çıktısı**: `Glob <OUT_DIR>/**/*.md` ile tüm dosyaları bul, hepsini Read et (paralel batch — tek mesajda çoklu Read tool call)
- **GitHub**: README + `docs/` klasörünün tüm `.md` dosyalarını `gh api` ile çek
- **Context7 (`ctx7` CLI)**: `npx ctx7@latest library <name> "<query>"` ile ID al, sonra `npx ctx7@latest docs <libraryId> "<query>"` çağrısını en az 3 farklı query ile yap (overview, API reference, examples) ki tüm doc coverage gelsin
- **Local file**: markitdown'un tam çıktısını Read et, parçalama

#### 4b) İçeriği Düzenle (Clean Pass)

Ham içerik üzerinde:
- Navigation/footer/cookie banner kalıntılarını sil (crawl2md zaten temizledi ama double-check)
- Tekrarlanan başlıkları birleştir
- Kod bloklarının dil etiketini kontrol et (```python, ```bash, ```json vb.)
- Kırık tablo markdown'larını düzelt
- Placeholder linkleri (`[click here]()`) kaldır

#### 4c) Sectioned Formata Yeniden Yapılandır

Düzenlenmiş içeriği profesyonel API reference şablonuna göre bölümle. Kaynakta bulunmayan bölümü atla — **uydurma yasak**.

| Section | İçerik formatı |
|---|---|
| overview | 2-3 paragraf açıklama, kullanım alanları, key features bullet list |
| auth | Authentication tipi, flow adımları, örnek header/token |
| endpoints | Her endpoint için: method + path + açıklama + params tablosu + response example |
| examples | Min 3 farklı senaryo, çalışır kod blokları (curl + en az 1 dil) |
| reference | Tüm parametreler: isim, tip, default, açıklama — markdown table |
| errors | HTTP status + error code + anlamı + çözüm — markdown table |
| rate_limits | Limit değerleri, window, header isimleri, aşım davranışı |
| sdk | Resmi SDK listesi: dil + paket adı + repo link |
| changelog | Son 3-5 sürüm notu, breaking changes vurgulu |

Her section markdown olarak **tam formatla**: başlıklar (`##`, `###`), tablolar, kod blokları, bullet list hiyerarşisi. Writer agent ham prose kabul eder ama **düzgün formatlı markdown beklenir** — agent kendisi format düzeltmez.

#### Bounded Extraction

- Crawl2md >50 markdown dosyası üretirse: `AskUserQuestion` (header: "Kapsam", options: ["İlk 50 dosya (depth azalt)", "Sadece index/toc sayfaları", "Custom glob", "Tamamı — büyük olabilir"])
- Toplam section payload >500KB olmasın — aşarsa kullanıcıya rapor, section içeriğini kırp (endpoints tablosunu kısaltma yerine reference'a taşı vb.)
- Kaynak çok büyükse (>200 sayfa): `AskUserQuestion` ile split öner — birden fazla source olarak kaydet (`stripe-api-core`, `stripe-api-webhooks`, vb.)

### 5) Writer'a Teslim

`Task` tool ile `obsidian-writer` (MODE: doc-source):

```
Task(
  description: "Docs kaynağı yaz",
  subagent_type: "obsidian-writer",
  prompt: "MODE: doc-source
TARGET: ~/Documents/ObsidianVault/docs/<source-name>
SOURCE_NAME: <source-name>
SOURCE_URL: <orijinal-kaynak>
SOURCE_TYPE: web|library|github|file
FETCHED_AT: <YYYY-MM-DD>
WRITE_MODE: overwrite|new_version   # çakışma kararından (yoksa 'create')

provenance: |
  ## Kaynak ve Edinim
  - **Birincil kaynak**: <kaynak + edinim yöntemi: Context7 library ID + sorgu sayısı / Stoplight-OpenAPI export / mail eki + dönüştürme yöntemi / WebFetch / crawl2md>
  - **İlgili referans**: <Zammad ticket no / mail konu-ID + varsa orijinal dosya yolu (örn. ~/Downloads/<dosya>.eml)>
  - **Credential'lar**: [[<credential-learnings-notu>]]   # varsa
  - **Doğrulama**: <✅/❌ + tarih + kısa sonuç (örn. "CreateTokenV2 ✅ 2026-06-11, token alındı")>

overview: |
  ...
endpoints: |
  ...
examples: |
  ..."
)
```

- **provenance (ZORUNLU)**: Writer bu bölümü index.md'ye "## Kaynak ve Edinim" olarak yazar. Frontmatter `source_url`/`fetched_at` tek başına yeterli DEĞİLDİR — görünür provenance bölümü şarttır (bkz. rules/obsidian.md "Doc-Source Provenance").
- **TARGET**: Global docs, proje folder'ı DEĞİL. Format: `~/Documents/ObsidianVault/docs/<source-name>/` (veya `-v2` vs. new_version seçildiyse)
- **WRITE_MODE**: `overwrite` → eski dosyalar silinir. `new_version` → ayrı klasör. `create` → hiç yok, yeni kurulum
- Writer global docs MOC'unu (`~/Documents/ObsidianVault/docs/index.md`) **tek sahip** olarak günceller. Skill dokunmaz.

### 6) Geçici Dizin Temizliği

Crawl2md kullanıldıysa:
```bash
rm -rf "$OUT_DIR"
```

### 7) Rapor

Writer'ın dönüş listesini kullanıcıya ilet.

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
| Obsidian Folder tanımsız | `/obsidian-init` öner ve iptal |

## Kurallar

- **Schema uydurma** — kaynakta olmayan endpoint/parametre yazma
- **Library için Context7 zorunlu** — kendi belleğinden React/Next.js yazma
- **Frontmatter** `source_url` + `fetched_at` writer tarafından eklenir
- **UTF-8 + Türkçe karakter** (kod blokları ve API isimleri İngilizce)
- **Commit etme** — skill sadece vault'a yazar, git'e dokunmaz
