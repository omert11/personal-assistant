## Obsidian Bellek Kullanımı

Proje `CLAUDE.local.md`'de `Obsidian Folder: <isim>` tanımlıysa, vault `~/Documents/ObsidianVault/<isim>/` altında MOC + [[wikilink]] yapısı vardır. mcp-obsidian araçları (`mcp__obsidian__*`) ile oku/yaz/ara.

## MCP Araçları

- `obsidian_list_files_in_dir(dirpath)` — Klasör içeriği
- `obsidian_get_file_contents(filepath)` — Tek dosya oku
- `obsidian_batch_get_file_contents(filepaths)` — Birden fazla dosya tek çağrıda oku
- `obsidian_simple_search(query, context_length=100)` — **Full-text** search (substring/BM25, **semantic DEĞİL**)
- `obsidian_complex_search(query)` — JsonLogic filter (path/content/tag)
- `obsidian_patch_content(filepath, ...)` — Heading/block/frontmatter'a göre içerik ekle
- `obsidian_append_content(filepath, content)` — Dosya sonuna ekle
- `obsidian_delete_file(filepath)` — Sil (dikkat)
- `obsidian_get_recent_changes(limit, days)` — Son değişen notlar
- `obsidian_get_periodic_note(period)` — daily/weekly/monthly/quarterly/yearly note

## Önce MOC, Sonra Search

SessionStart hook'u `index.md`'nin başlıklarını kontext'e yükler. Bir bilgi ararken:

1. **MOC'ta [[wikilink]] varsa**: Direkt `obsidian_get_file_contents("<folder>/<link>.md")` çağır. Search yapma.
2. **MOC'ta yoksa**: `obsidian_list_files_in_dir("<folder>")` veya alt klasörleri (`Learnings/`, `Journal/`) tara. Dosya adı bulursan oku.
3. **Hala bulamazsan**: `obsidian_simple_search("<query>")` kullan. Match listesinden ilgiliyi oku.

## Search Kurallari

- **Full-text**: Sorgu kelimesi notta **literal** geçiyor olmalı. "SSH" ararken "remote access" bulunmaz.
- **Sinonim/yeniden ifade dene**: İlk query boş dönerse 2-3 alternatif terimle tekrar (örn: "Hetzner" → "ssh key" → "credential").
- **Path prefix**: Query'ye `Learnings/` veya `Journal/` ekleme. Search tüm vault'u tarar, filter için `complex_search` kullan.
- **Vector search yok**. Kavramsal sorular için önce MOC'a bak, sonra search'i keyword varyantlarıyla yinele.
- **Limit**: Search sonucu çok gelirse `context_length` düşür (default 100). İlk 3-5 match'e bak.

## Yazma Kurallari

- **Direkt write yapma**. Append/patch için `obsidian-writer` agent'ını `MODE: append` ile çağır (`Task` tool). Agent MOC index.md'yi günceller, dedup eder, frontmatter doğru yazar.
- **Ad-hoc "not al" isteklerinde**: `/obsidian-note` skill tetikle veya `obsidian-writer` agent'ı çağır.
- **Stop hook otomatik tetiklenir**: Kullanıcı paylaştığı kayda değer bilgi (API key, sunucu, karar) varsa oturum sonunda main agent'tan writer'ı çağırması istenir.

## Mevcut Notu Güncelleme

Aynı konuda mevcut not varsa `obsidian-writer` onu bulur ve `## {date}` başlığıyla append eder. Manuel yapman gerekirse:

1. `obsidian_simple_search(topic)` ile bul
2. `obsidian_patch_content(filepath, operation="append", target_type="heading", target="{date}")` veya
3. `obsidian_append_content(filepath, content)` ile sona ekle

## Klasör Konvansiyonu

- `index.md` — MOC (her zaman)
- `Stack.md`, `Architecture.md`, `Recent-Activity.md`, `README-Summary.md` — init agent çıktıları
- `Learnings/<topic>.md` — Kalıcı bilgiler (API key, sunucu, kural, teknik karar)
- `Journal/<YYYY-MM-DD>.md` — Zamanlı oturum özetleri

## Ne Zaman Obsidian, Ne Zaman Memory

- **Obsidian** → Proje-spesifik kalıcı bilgi (bu projenin DB şifresi, bu projenin mimari kararı)
- **`~/.claude/memory/`** → Kullanıcı profili, genel feedback, cross-project referanslar
- **`~/.claude/rules/`** → Tüm projelerde geçerli kurallar (bu dosya gibi)
