## Obsidian Bellek Kullanımı

Proje `CLAUDE.local.md`'de `Obsidian Folder: <isim>` tanımlıysa, vault `~/Documents/ObsidianVault/<isim>/` altında MOC + [[wikilink]] yapısı vardır. **Resmi Obsidian CLI** (`obsidian` komutu, Settings → General → Advanced → Command line interface ile aktifleşir) ile oku/yaz/ara. Komutlar Obsidian app açıkken çalışır. Komutların tamamı: `obsidian help`.
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
