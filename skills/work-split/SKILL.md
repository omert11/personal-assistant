---
name: work-split
description: Çok maddeli kaynağı numaralı işlere, ajan gruplarına ve orkestratör promptlarına böler.
when_to_use: Trigger — "işleri grupla", "ajanlara böl", "toplantı notlarını analiz et", "iş analizi çıkar", "orkestratör promptu hazırla", "bu dokümanı işlere ayır", "/work-split <kaynak>". Kaynak birden fazla orkestratör oturumuna dağıtılacaksa; tek iş için orchestrate yeterli.
argument-hint: <dosya-yolu | serbest-metin>
disable-model-invocation: false
effort: max
allowed-tools: Agent, Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion, Skill
---

# Work Split

Analistsin: kod yazma, çözüm önerme. Yalnız "ne" ve "neden" yaz; "nasıl" orkestratörün.

## 1. Kaynak

- Metnin tamamını ve görselleri oku; her görseli maddesiyle eşle.
- Somut referansları (PNR, dosya no, rezervasyon/sepet ID, URL, ekran) listele.
- `AGENTS.md`, git log, açık PR'lar ve önceki raporlardan yeni işlerin üzerine geleceği bağlamı çıkar.

## 2. Numaralama

- Her bağımsız istek/sorun bir iş; kaynak sırası korunur.
- Biçim: alan öneki + sıra (`UCK-01`, `OTL-03`, `GNL-02`). Numara kalıcıdır; silinen numara yeniden verilmez.
- Ajan işi olmayan maddeler (dış tarafa sorulacak, karar) ayrı önekle "İş dışı"na.
- Yorum cümleleri ("baştan yazılabilir", "tüm ürünlerde kontrol edilmeli") ilgili işin notudur; açık kapsam genişletmesi ise ayrı numara alır.

## 3. Analiz

- Referansları canlı veride ve kodda salt-okur doğrula; yazma ve deneme işlem yok.
- Bulguyu olgu olarak yaz (değer, durum, kimlik); kök neden yerine "uyuşuyor / çelişiyor".
- Doğru karar netse kararı al, "Karar" olarak yaz. Yalnız kullanıcı onayı veya kararı kesin gerekiyorsa "Açık soru" yap.
- Her iş: **Not** (kısa alıntı), **Sorun / İstek** (etki: mali, deneyim, operasyon), **Canlı veri / Kanıt**, **Beklenen** (sonuç, yöntem değil), **Kapsam** (ürün, kanal, tenant, dışarıda kalan), **Bağlam / İlişki**, **Karar**, **Açık soru** (yalnız kullanıcı kararı gerekiyorsa), **Kabul** (görsel, matris, ölçüm, tablo).
- Çözüm adımı, dosya değişikliği tarifi, mimari öneri yazma.

## 3b. Açık sorular

- Tüm açık soruları prompt üretmeden önce soru aracıyla tek blokta sor; cevapları "Karar"a çevir.

## 4. Gruplar

- Grup = tek orkestratör oturumu. Ölçüt sırası: alan bütünlüğü (aynı akış, kod bölgesi, sağlayıcı) → zorluk (Kritik / Zor / Orta / Kolay; mali risk ve geri dönüşsüz iş en üstte) → boyut (büyükse alt gruba böl, küçükse alan komşusuna kat).
- "Hızlı işler" grubu yalnız dosya çakışması yaratmıyorsa kurulur.
- Her grup: işler, zorluk, dalga, sınır (neyin bu grubun, neyin başkasının).
- Aynı ekran/bileşene dokunan iki grupta sahip tek grup olur; diğeri kullanır, değiştirmez.

## 5. Sıra ve çakışma

- Aynı dosyalara dokunan grupları ve paralelde çıkacak rebase çakışmasını yaz.
- Dalga 1: alanı ayrık ve en yüksek mali öncelikli gruplar. Sonrakiler: ortak yapıyı değiştiren önce, üzerine kuran sonra.
- Yapısal değişiklik yapan grup raporunda sonraki gruplara not bölümü bırakır.

## 6. Analiz dosyası

- Yol: repo kökünde git dışı `.agents/<konu-tarih>/<konu>-is-analizi.md`.
- Bölümler: ortak bağlam (ortam kimlikleri, ilgili son değişiklikler tablosu) → özet tablo (No · Konu · Ürün · Zorluk · Grup) → alan bölümleri (`### <NO> · <başlık>`) → iş dışı → ajan grupları tablosu → her grup `### Grup <X> · <ad>` → çakışma ve çalıştırma sırası.
- Başlıklar promptlarda birebir alıntılanır; sabit tut.

## 7. Orkestratör promptları

- Yol: aynı klasörde `orkestrator-promptlari.md`; kullanım (yeni oturum, yapıştır, dalga sırası), genel şablon, grup başına kopyala-yapıştır prompt.
- Her prompt kendi başına yeterli ve şunları içerir:
  - Analiz dosyasının mutlak yolu, `Grup <X> · <ad>` bölümü, iş numaraları; ortak bağlam ve sıra bölümlerini okuma talimatı.
  - `orchestrate` skill ile çalış; önce sorunu kodda doğrula; analizdeki Kararlara uy.
  - `AGENTS.md` ve worktree izolasyonu; grup sınırı dışına çıkma.
  - Kanıt yalnız görsel işte (arayüz değişikliği): ekran görüntüsü `.agents/<konu-tarih>/kanit/grup-<x>/<iş-no>/` altına; diğer işlerde kodla doğrulama (diff, build, test) yeterli, kanıt toplanmaz.
  - Commit/PR başlığında iş numarası; `commit` skill ile teslim; COMMIT_RULES gereği release notes.
  - Canlıda geri dönüşsüz işlem (satış, bilet, void, iade, müşteriye/tedarikçiye e-posta, prod yazma) önce sorulur.
  - Bitişte `user-report` ile iş numarası bazlı rapor (sorun → kök neden → yapılan → kanıt → PR/sürüm → açık kalanlar), `rapor-grup-<x>.html`, `dw-share` ile gönderim.
  - Gruba özel notlar: ölçüm beklentisi, diğer gruplarla sınır.
  - Zor/kritik grupta son satır `ultrathink`.

## 8. Doğrulama ve teslim

- Her prompttaki grup başlığı ve iş numarası analiz dosyasında birebir başlık olarak var olmalı.
- Her iş bir gruba ya da "İş dışı"na ait olmalı.
- İki dosyayı `dw-share` ile gönder; sohbete grup/dalga tablosu ve öne çıkan canlı veri bulgularını kısa yaz.
