# Init

Her konuşmanın ilk mesajında, ne sorulursa sorulsun, önce şunları kontrol et:

1. `CLAUDE.md` mevcut mu
2. `CLAUDE.local.md` mevcut mu
3. `CLAUDE.local.md` içinde Vikunja proje ID tanımlı mı
4. `CLAUDE.local.md` içinde Solo proje ID tanımlı mı
5. `CLAUDE.local.md` içinde Stitch proje ID tanımlı mı

Bu 5 maddenin herhangi biri eksikse, ilk çıktının sonuna ayrı bir bölüm olarak ekle:

> ⚠️ **Eksik Yapılandırma**: Eksikleri tamamlamak için `/project-init` komutunu çalıştırabilirsiniz.

## Vikunja Görev Kontrolü

Eğer kullanıcı bir sorun/hata/görev bildiriyorsa ve `CLAUDE.local.md`'de Vikunja proje ID tanımlıysa:

1. Vikunja'da bu sorunla ilgili mevcut bir görev var mı kontrol et
2. Görev varsa: görevi referans al ve üzerinden ilerle
3. Görev yoksa: `AskUserQuestion` ile sor (header: "Vikunja", question: "Bu sorun için Vikunja'da görev bulunamadı. Oluşturayım mı?", options: ["Evet", "Hayır"])
