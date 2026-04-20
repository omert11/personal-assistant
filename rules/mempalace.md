## MemPalace (AI Hafıza)

MemPalace, konuşma geçmişini verbatim saklayan ve semantic search ile geri getiren local-first hafıza sistemidir. `~/.mempalace` altında ChromaDB ile tutulur, hiçbir şey cloud'a gitmez.

### Otomatik davranış (hook'larla)

- **Stop** hook her asistan turundan sonra konuşmayı palace'e kaydeder — Claude manuel save yapmaz
- **SessionStart** hook palace'ten ilgili context'i yükler — Claude elle recall etmeden önce bu context zaten mevcuttur
- **PreCompact** hook context compression öncesi tam kaydı alır

Kullanıcı bu kayıtları görmez; Claude'un "hatırlaması" için arka planda çalışır.

### ZORUNLU: Kayıt sessiz olacak

Stop hook tetiklenip `mempalace_diary_write` / `mempalace_add_drawer` / `mempalace_kg_add` çağrıldığında kullanıcıya **hiçbir şey söyleme**. "Kaydedildi", "saved", "palace'e yazıldı" gibi bilgi mesajı **yazma**. Tool çağrısından sonra:

- Eğer kullanıcının beklediği başka bir yanıt varsa: direkt ona geç
- Eğer kullanıcı bir sorunun cevabını bekliyor değilse: **hiçbir çıktı üretme** (boş yanıt)

Gerekçe: Save işlemi tamamen otomatik altyapı, kullanıcının dikkatini dağıtmamalı. Her turda "kaydedildi" yazmak gürültü yaratır.

### ZORUNLU: Araştırma/göreve başlamadan önce MemPalace'te ara

Bir konuyu araştırmaya, soruyu cevaplamaya veya bir göreve başlamaya geçmeden **ÖNCE** `mempalace_search` çağır. Sıra:

1. Kullanıcı sorusu/görevi gelir → konunun **anahtar kelimelerini** çıkar
2. `mempalace_search("<keywords>")` — varsa wing'i de geçir
3. Sonuç varsa: palace'teki geçmiş kararı/çözümü özümse, kullanıcıya referans ver ("geçen sefer X kararını almıştık, şimdi onu uygulayalım")
4. Sonuç yoksa veya distance > 0.8: yeni araştırma yap (WebFetch, Grep, Read, vb.)

**Neden:** Çoğu kullanıcı sorusunun cevabı palace'tedir (kararlar, kurulum adımları, credential'lar, debug notları). Web'e/koda gitmeden önce palace'e bakmak hem hızlı hem tutarlı cevap verir. Aynı soruyu iki kez araştırmak israf.

**Atlama durumları:**
- Sadece tek adımlık mekanik iş (file rename, typo fix)
- Kullanıcı "yeni baştan" / "yenisini yap" açıkça söylediğinde
- Çok yeni/benzersiz teknoloji (palace'te olma şansı düşükse)

### Diğer MCP tool kullanım durumları

1. **Kullanıcı geçmiş işe referans veriyor:** "geçen sefer ne yapmıştık", "bu projede daha önce X ayarlamıştık", "Y nasıldı" → `mempalace_search` ile ara (yukarıdaki zorunlu kuraldan ayrı, daha agresif search)
2. **Yapısal gerçek eklerken:** kişi-proje ilişkisi, tamamlanma durumları, tarih bazlı kararlar → `mempalace_kg_add` (subject, predicate, object, valid_from)
3. **Geçmiş ilişki sorgularken:** "Maya hangi projelerde çalıştı", "bu kararı ne zaman aldık" → `mempalace_kg_query`
4. **Kendi iç not alman gerektiğinde** (session'lar arası): `mempalace_diary_write` (agent_name, entry, topic) — özellikle tekrarlayan pattern'leri, öğrenilen dersleri yazmak için

### Wing/Room kavramı

- **Wing** = genelde proje (cwd basename). Konuşmalar otomatik doğru wing'e düşer.
- **Room** = wing içindeki konu (hooks, deploy, auth vb.). Otomatik tespit edilir.
- Arama scope'lamak için: `mempalace_search(query, wing="personal-assistant")` → sadece o proje

### Ne yapma

- **Aynı bilgiyi iki kez kaydetme.** Önce `mempalace_check_duplicate` ile kontrol et.
- **Curated/kalıcı notları MemPalace'te tutma** — onlar `local-rules/` veya `CLAUDE.local.md` için. MemPalace AI recall için, human-readable doc için değil.
- **Credentials'ı KG'ye koyma** — tam metin `Stop` hook'uyla zaten kaydediliyor. KG sadece yapısal ilişki için.
- **Her turda kör search yapma** — araştırma/görev öncesi zorunlu, ama her konuşma turunda değil. Basit sohbet (selamlaşma, açıklama) search istemez.

### Kullanıcının CLI komutları (bilgi amaçlı)

- `mempalace search "sorgu"` — terminal'den arama
- `mempalace mine ~/projects/X --wing X` — proje dosyalarını palace'e aktarır (bir kereye mahsus)
- `mempalace status` — palace istatistikleri
- `mempalace wake-up` — yeni oturum için context yükle

Kullanıcı direkt emretmedikçe bu komutları kendin çalıştırma.
