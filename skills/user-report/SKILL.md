---
name: user-report
description: Yapılan işi veya bir konuyu tek dosyalık, görsel zengin HTML rapor olarak sunar.
when_to_use: Trigger — "rapor hazırla", "görsel özet", "yaptıklarımızı özetle", "önce/sonra göster", "html rapor", "/user-report". Kullanıcı bir işin, analizin veya karşılaştırmanın tek bakışta görsel özetini istediğinde.
argument-hint: [konu]
---

# User Report

## İçerik

- Saf gerçek: her sayı repo, dosya sistemi veya komut çıktısından ölçülür; tahmin yok.
- Tek bakışta anlaşılır: önce özet, sonra detay. Gereksiz metin yok; etiket ve kısa cümle.
- Değişiklik varsa önce/sonra karşılaştırması: sayı, oran, silinen/eklenen/değişen.
- Yaptığın çalışmayı tek bakışta anlaşılacak şekilde görselleştir: grafik, diyagram, ikon, renk.
- Bekleyen işler ve riskler ayrı gösterilir.

## Teknik

- Tek dosya: `/tmp/<konu-slug>.html`; harici yerel dosya yok.
- Hazır kütüphaneler CDN'den: Tailwind (yerleşim), Chart.js (grafik), Mermaid (diyagram), Lucide (ikon). Grafik/ikon/diyagramı elle çizme.

## Doğrulama ve teslim

1. Headless tarayıcıda aç (`file://` açılamıyorsa klasörü geçici yerel HTTP ile sun, sonra kapat); konsol hatası, çizilmeyen grafik/diyagram, taşma kontrol et; tam sayfa görüntüye bak, düzelt.
2. Kullanıcının varsayılan tarayıcısında aç: `open /tmp/<konu-slug>.html`.
3. Sohbete dosya yolu + bir satır özet.
