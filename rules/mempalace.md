## MemPalace (AI Hafıza)

MemPalace, konuşma geçmişini verbatim saklayan ve semantic search ile geri getiren local-first hafıza sistemidir. `~/.mempalace` altında ChromaDB ile tutulur, hiçbir şey cloud'a gitmez.

### Otomatik davranış (hook'larla)

- **Stop** hook her asistan turundan sonra konuşmayı palace'e kaydeder — Claude manuel save yapmaz
- **SessionStart** hook palace'ten ilgili context'i yükler — Claude elle recall etmeden önce bu context zaten mevcuttur
- **PreCompact** hook context compression öncesi tam kaydı alır

Kullanıcı bu kayıtları görmez; Claude'un "hatırlaması" için arka planda çalışır.

### Ne zaman MCP tool'larını çağırmalı

Aşağıdaki durumlarda `mempalace_*` tool'larını kullan:

1. **Kullanıcı geçmiş işe referans veriyor:** "geçen sefer ne yapmıştık", "bu projede daha önce X ayarlamıştık", "Y nasıldı" → `mempalace_search` ile ara
2. **Karmaşık göreve başlamadan:** benzer iş daha önce yapılmış mı kontrol et (çözüm tekrar üretme riski varsa) → `mempalace_search`
3. **Yapısal gerçek eklerken:** kişi-proje ilişkisi, tamamlanma durumları, tarih bazlı kararlar → `mempalace_kg_add` (subject, predicate, object, valid_from)
4. **Geçmiş ilişki sorgularken:** "Maya hangi projelerde çalıştı", "bu kararı ne zaman aldık" → `mempalace_kg_query`
5. **Kendi iç not alman gerektiğinde** (session'lar arası): `mempalace_diary_write` (agent_name, entry, topic) — özellikle tekrarlayan pattern'leri, öğrenilen dersleri yazmak için

### Wing/Room kavramı

- **Wing** = genelde proje (cwd basename). Konuşmalar otomatik doğru wing'e düşer.
- **Room** = wing içindeki konu (hooks, deploy, auth vb.). Otomatik tespit edilir.
- Arama scope'lamak için: `mempalace_search(query, wing="personal-assistant")` → sadece o proje

### Ne yapma

- **Aynı bilgiyi iki kez kaydetme.** Önce `mempalace_check_duplicate` ile kontrol et.
- **Curated/kalıcı notları MemPalace'te tutma** — onlar `local-rules/` veya `CLAUDE.local.md` için. MemPalace AI recall için, human-readable doc için değil.
- **Credentials'ı KG'ye koyma** — tam metin `Stop` hook'uyla zaten kaydediliyor. KG sadece yapısal ilişki için.
- **Her turda search yapma** — sadece kullanıcı geçmişe referans verdiğinde veya karmaşık iş öncesinde.

### Kullanıcının CLI komutları (bilgi amaçlı)

- `mempalace search "sorgu"` — terminal'den arama
- `mempalace mine ~/projects/X --wing X` — proje dosyalarını palace'e aktarır (bir kereye mahsus)
- `mempalace status` — palace istatistikleri
- `mempalace wake-up` — yeni oturum için context yükle

Kullanıcı direkt emretmedikçe bu komutları kendin çalıştırma.
