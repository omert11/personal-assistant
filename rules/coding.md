# Coding

## Dil Ayrımı
- İletişim Türkçe, kod yorumları ve commit mesajları İngilizce

## Proaktif Hijyen
- Unused import, typo, formatting gibi küçük ihlalleri sessizce düzelt
- Mimari ihlal (güvenlik açığı, yanlış pattern kullanımı vb.) görürsen işlemi DURDUR ve `AskUserQuestion` ile raporla (header: "Ihlal", options: ["Düzelt", "Görmezden gel"])

## Otonom Çözüm
- Hata/log verildiğinde yönlendirme bekleme, analiz et ve çöz

## Self-Check
- Her değişiklikte "Daha zarif/basit bir yol var mı?" diye kontrol et
- Geçici çözüm (workaround) üretme, doğru çözümü bul

## Hata Yönetimi
- Hataları her zaman wrap et, çıplak hata fırlatma (Go: `fmt.Errorf(": %w", err)`, Python: `raise X from err`)

## TODO Kuralları
- Kod içinde sonradan değiştirilmesi, tamamlanması veya yapılandırılması gereken alanlar varsa `# TODO: ...` yorumu ekle
- Örnekler: hard-coded değerler, placeholder metinler, geçici çözümler, eksik validasyonlar, ileride eklenecek özellikler
