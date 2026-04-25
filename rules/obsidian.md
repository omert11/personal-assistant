## Obsidian Bellek Kullanımı

Proje `CLAUDE.local.md`'de `Obsidian Folder: <isim>` tanımlıysa, vault `~/Documents/ObsidianVault/<isim>/` altında MOC + [[wikilink]] yapısı vardır. **Resmi Obsidian CLI** (`obsidian` komutu, Settings → General → Advanced → Command line interface ile aktifleşir) ile oku/yaz/ara. Komutlar Obsidian app açıkken çalışır.

## CLI Komutları (Bash tool ile çağır)

- `obsidian read path=<folder/note.md>` — Tek dosya oku (vault root'a göre relative path)
- `obsidian files folder=<folder>` — Klasör içeriği listele
- `obsidian search query="<text>" format=json` — Full-text search (Obsidian index, BM25)
- `obsidian search:context query="<text>" format=json` — Match satırı + context ile
- `obsidian append path=<folder/note.md> content="<text>"` — Dosya sonuna ekle
- `obsidian prepend path=<folder/note.md> content="<text>"` — Dosya başına ekle
- `obsidian create name=<note> path=<folder/> content="<text>"` — Yeni dosya
- `obsidian delete path=<folder/note.md>` — Sil (dikkat — `permanent` flag çöpü atlar)
- `obsidian recents` — Son açılan dosyalar
- `obsidian daily:read` / `daily:append content="<text>"` — Daily note
- `obsidian outline path=<folder/note.md> format=json` — Heading listesi
- `obsidian properties path=<folder/note.md>` — Frontmatter property'leri
- `obsidian property:set name=<key> value=<v> path=<folder/note.md>` — Property güncelle
- `obsidian backlinks path=<folder/note.md>` — Bağlantılar
- `obsidian tags counts format=json` — Vault tag listesi

> Vault seçimi: tek vault varsa otomatik. Çoklu vault için `vault="<name>"` flag'i ekle. Komutların tamamı: `obsidian help`.

## Önce MOC, Sonra Search

SessionStart hook'u `index.md`'nin başlıklarını kontext'e yükler. Bir bilgi ararken:

1. **MOC'ta [[wikilink]] varsa**: Direkt `obsidian read path=<folder>/<link>.md` çağır. Search yapma.
2. **MOC'ta yoksa**: `obsidian files folder=<folder>` ile listele (alt klasörler `Learnings/`, `Journal/`). Dosya adı bulursan oku.
3. **Hala bulamazsan**: `obsidian search query="<query>" format=json`. Match listesinden ilgiliyi oku.

## Search Kuralları

- **Full-text + BM25**: Obsidian'ın native search index'i. Sorgu kelimesi notta literal geçiyor olmalı.
- **Sinonim dene**: İlk query boş dönerse 2-3 alternatif terimle tekrar (örn: "Hetzner" → "ssh key" → "credential").
- **Path filter**: `path=<folder>` parametresiyle alt klasöre kısıtla (örn. `path=Learnings`).
- **Vector search yok**. Kavramsal sorular için önce MOC'a bak, sonra search'i keyword varyantlarıyla yinele.
- **Limit**: `limit=<n>` ile match sayısını sınırla. İlk 3-5 match'e bak.
- **JSON format**: `format=json` ile parse edilebilir çıktı al, default text okunur ama parse zor.

## Yazma Kuralları

- **Direkt CLI write yapma** (ad-hoc append hariç). Yapısal yazımlar için `obsidian-writer` agent'ını `MODE: append` ile çağır (`Task` tool). Agent MOC index.md'yi günceller, dedup eder, frontmatter doğru yazar.
- **Ad-hoc "not al" isteklerinde**: `/obsidian-note` skill tetikle veya `obsidian-writer` agent'ı çağır.
- **Stop hook otomatik tetiklenir**: Kullanıcı paylaştığı kayda değer bilgi (API key, sunucu, karar) varsa oturum sonunda main agent'tan writer'ı çağırması istenir.

## Mevcut Notu Güncelleme

Aynı konuda mevcut not varsa `obsidian-writer` onu bulur ve `## {date}` başlığıyla append eder. Manuel yapman gerekirse:

1. `obsidian search query="<topic>" format=json` ile bul
2. `obsidian append path=<folder/note.md> content="\n## {date}\n<text>"` ile sona ekle
3. Heading altına spesifik insert için: `obsidian outline path=<...>` ile heading listesini al, sonra `Edit` tool ile dosyayı düzenle

## Klasör Konvansiyonu

- `index.md` — MOC (her zaman)
- `Stack.md`, `Architecture.md`, `Recent-Activity.md`, `README-Summary.md` — init agent çıktıları
- `Learnings/<topic>.md` — Kalıcı bilgiler (API key, sunucu, kural, teknik karar)
- `Journal/<YYYY-MM-DD>.md` — Zamanlı oturum özetleri

## Ne Zaman Obsidian, Ne Zaman Memory

- **Obsidian** → Proje-spesifik kalıcı bilgi (bu projenin DB şifresi, bu projenin mimari kararı)
- **`~/.claude/memory/`** → Kullanıcı profili, genel feedback, cross-project referanslar
- **`~/.claude/rules/`** → Tüm projelerde geçerli kurallar (bu dosya gibi)

## Fallback (Obsidian Kapalıysa)

CLI komutları Obsidian app açık değilse hata verir (`No active vault`). Bu durumda:

- **Read-only erişim**: `Read`, `Glob`, `Grep` tool'ları ile vault dosyalarına direkt filesystem üzerinden eriş (`~/Documents/ObsidianVault/<folder>/...`)
- **Write**: Obsidian'ı aç (`open -a Obsidian`) sonra CLI komutu çalıştır
