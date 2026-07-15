# User Render

## Artifact Tool Yerine user-render — ZORUNLU

Kullanıcıya bir konuyu **görsel HTML sayfasıyla** anlatmak/sunmak gerektiğinde (analiz, rapor,
karşılaştırma, plan, kanıt sayfası, dashboard):

- **Artifact tool KULLANMA** — sayfa claude.ai'ye yüklenmez, lokalde kalır.
- **`user-render` skill'ini çağır** — dosya düzeni (`~/.pa-render/active/<konu>/index.html`),
  hazır UI kit (`/lib/pa.css` + `/lib/pa.js` bileşenleri) ve arşivleme akışı orada tanımlı.
- Sen yalnız dosyayı yazar/güncellersin; sayfayı **sunmaz, açmaz, server yönetmezsin** — takibi
  kullanıcı kendi ekranından yapar.

**İstisna:** Kullanıcı açıkça "Artifact olarak yayınla / claude.ai'ye yükle / paylaşılabilir link"
derse Artifact tool kullanılır.

Terminal metniyle yeterince anlatılabilen kısa cevaplar için sayfa üretme — bu kural yalnız
görsel sayfanın gerçekten değer kattığı durumlar içindir (issue-workflow analiz sayfaları,
çok boyutlu karşılaştırmalar, kanıtlı raporlar).
