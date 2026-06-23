# Init

Her konuşmanın ilk mesajında, ne sorulursa sorulsun, önce şunları kontrol et:

1. `CLAUDE.md` mevcut mu
2. `CLAUDE.local.md` mevcut mu
3. `CLAUDE.local.md` içinde Solo proje ID tanımlı mı
4. `CLAUDE.local.md` içinde Obsidian Folder tanımlı mı

Bu 4 maddenin herhangi biri eksikse, ilk çıktının sonuna ayrı bir bölüm olarak ekle:

> ⚠️ **Eksik Yapılandırma**: Eksikleri tamamlamak için `/project-init` komutunu çalıştırabilirsiniz.

> NOT: Görev takibi (Plane proje) **opsiyoneldir** — tanımlı değilse uyarı verilmez, Claude native TaskCreate/TaskUpdate yeterlidir.

## Plane Görev Kontrolü (opsiyonel)

Eğer kullanıcı bir sorun/hata/görev bildiriyorsa ve `CLAUDE.local.md`'de Plane proje (UUID) tanımlıysa:

1. Plane'de bu sorunla ilgili mevcut bir issue var mı kontrol et (`plane-cli issue search`)
2. Issue varsa: referans al ve üzerinden ilerle
3. Issue yoksa: `AskUserQuestion` ile sor (header: "Plane", question: "Bu sorun için Plane'de issue bulunamadı. Oluşturayım mı?", options: ["Evet", "Hayır"])

Plane proje tanımlı DEĞİLSE bu kontrol atlanır (TaskCreate ile takip yeterli).

## Obsidian Learnings Ön Arama

Kullanıcı oturumda **ilk somut görevi** verdiğinde (sorun bildir, değişiklik iste, bug çöz, feature ekle, refactor vb.) ve `CLAUDE.local.md`'de `Obsidian Folder: <isim>` tanımlıysa, göreve başlamadan önce geçmiş Learnings notlarını ara.

**Nasıl**: Arama mantığını elle yürütme — `obsidian-searcher` agent'ını `run_in_background: true` ile çağır (QUERY: görevin özeti, FOLDER: obsidian folder). Agent "önce MOC → BM25 search → context → not oku" akışıyla ilgili notları bulup sentezler. Bulgu varsa bağlam olarak kullan; kullanıcıya "şu Learnings notu ilgili görünüyor" diye kısaca belirt, sonra göreve başla. (Bu hatırlatma ayrıca UserPromptSubmit hook'u ile her somut prompt'ta otomatik enjekte edilir.)

**Tetiklenmediği durumlar**: Selamlaşma, kavramsal soru ("X nedir?"), dosya listeleme gibi trivial istekler — arama yapılmaz.

**Amaç**: Daha önce yazılmış proje-spesifik kuralları (DB şifresi, bilinen sorun, tasarım kararı) tekrar sormadan kullanmak.
