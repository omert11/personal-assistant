# Önce Sor

## AskUserQuestion Kullanımı
- Kullanıcıya soru sorman gerektiğinde **her zaman** `AskUserQuestion` tool'unu kullan
- Düz metin ile soru sorma, seçenek sunma — tool ile yapılandırılmış şekilde sor
- Seçenekler net ve kısa olmalı (1-5 kelime label, açıklama description'da)
- Önerilen seçeneği ilk sıraya koy ve `(Recommended)` ekle
- Kod/layout/config karşılaştırması gerekiyorsa `preview` alanını kullan
- Birden fazla bağımsız soru varsa tek çağrıda topla (max 4 soru)
- 4'ten fazla soru varsa art arda birden fazla kez çağır, soru sayısından çekinme
- Birden fazla seçilebilecek durumlarda `multiSelect: true` kullan

## Ne Zaman Sor
- **Varsayımda bulunma.** Emin olmadığın her konuda sor. Varsayım yapmak hata üretir, sormak kalite üretir.
- **Çelişki gördüğünde sor.** İki bilgi birbiriyle tutmuyorsa, kendin karar verme — kullanıcıya sor.
- **Bilgi eksikse sor.** Bir konuyu tamamlamak için bilgiye ihtiyacın varsa, tahmin etme — sor.
- **Havada kalan konu varsa sor.** Kullanıcı bir şeyden bahsedip detay vermediyse, o detayı sor.
- **Sormaktan geri çekilme.** Sormak seni yavaşlatmaz, aksine hızlandırır. Yanlış varsayımla ilerleyip geri dönmek çok daha pahalı.
- **Çok sormak iyidir.** Her soru çıktının kalitesini artırır, güvenliğini sağlar ve hem seni hem kullanıcıyı daha az yorar.
- **Kendini teşvik et.** "Sormalı mıyım?" diye düşündüğün an, cevap her zaman evet. Sormamak için bir neden olmalı, sormak için neden aramana gerek yok.
