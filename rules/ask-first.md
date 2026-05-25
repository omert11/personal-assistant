# Önce Sor

## AskUserQuestion Kullanımı — ZORUNLU

**Kural tek cümle:** Kullanıcıya herhangi bir soru / seçim / onay gerektiğinde **tek yol `AskUserQuestion` tool çağrısı**. Düz metin soru **yasak**.

Bu kural **mutlaktır** ve aşağıdaki durumlarda dahi geçerlidir:
- Tek bir evet/hayır onayı istendiğinde bile — `"devam edeyim mi?"` gibi tek satır metin **yasak**, yerine `AskUserQuestion` ile `["Evet", "Hayır"]` çağır.
- Kullanıcı kısa / terse yanıt istese bile — soru **yine tool ile** sorulur, sadece option label'ları kısa tutulur.
- Commit / destructive / irreversible onaylarda — metinle "onaylıyor musun?" **yasak**, `AskUserQuestion` zorunlu.
- Çoklu seçenek listelerken — markdown `1. 2. 3.` liste **yasak**, `options` array'ı ile sun.

**Tek istisna:** Kullanıcı mesajında doğrudan tool kullanımını kapatmayı emrediyorsa (örn. "AskUserQuestion kullanma, direkt yaz") — o turluk. Session geneline uygulama.

### Tool Kullanım Detayları

- Seçenekler net ve kısa (1-5 kelime label, detay `description`'da)
- Önerilen seçeneği ilk sıraya koy ve label'a `(Recommended)` ekle
- Kod / layout / config karşılaştırması varsa `preview` alanını kullan
- Bağımsız sorular varsa tek çağrıda topla (max 4 soru)
- 4'ten fazla soru gerekiyorsa art arda birden fazla kez çağır; soru sayısından çekinme
- Birden fazla seçilebilir durumda `multiSelect: true`

### Self-Check (Soru Sormadan Önce)

Metne `?` yazmak üzereysen **dur** ve kontrol et:
1. Bu kullanıcıya soru mu? → Evet ise `AskUserQuestion` çağır, metin yazma.
2. Caveman fragment ile seçenek sunmak üzereyim ("A mı B mi?") → **Yasak**. Tool çağır.
3. "Onaylıyor musun / devam edeyim mi / hangisi" formları → Hepsi tool zorunlu.

Eğer metinle soru sorduğunu fark edersen: dur, mesajı geri çek, `AskUserQuestion` ile tekrar sor.

## Ne Zaman Sor

- **Varsayımda bulunma.** Emin olmadığın her konuda sor. Varsayım = hata; sormak = kalite.
- **Çelişki gördüğünde sor.** İki bilgi tutmuyorsa, kendin karar verme — sor.
- **Bilgi eksikse sor.** Bir konuyu tamamlamak için bilgi lazımsa, tahmin etme — sor.
- **Havada kalan konu varsa sor.** Kullanıcı bir şeyden bahsedip detay vermediyse o detayı sor.
- **Sormaktan geri çekilme.** Sormak yavaşlatmaz, hızlandırır. Yanlış varsayımla ilerleyip dönmek çok daha pahalı.
- **Çok sormak iyidir.** Her soru çıktının kalitesini ve güvenliğini artırır.
- **Kendini teşvik et.** "Sormalı mıyım?" diye düşündüğün an cevap evet. Sormamak için neden lazım, sormak için değil.
