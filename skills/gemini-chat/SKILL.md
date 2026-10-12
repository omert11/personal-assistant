---
name: gemini-chat
description: Kullanıcının oturum açık Chrome'undaki Gemini ile sohbet eder, görsel üretir ve indirir.
when_to_use: Trigger — "gemini'ye sor", "gemini ile görsel oluştur", "gemini'de resim çiz", "gemini chat", "/gemini-chat". Gemini'nin kendi cevabı veya Gemini'de üretilen görsel gerektiğinde.
argument-hint: [soru veya görsel tarifi]
---

# Gemini Chat

Kullanıcının oturum açık tarayıcısındaki Gemini sekmesini `${CLAUDE_SKILL_DIR}/scripts/gemini.js` ile yönet. Akış, bekleme, kurtarma ve indirme script'te; elle DOM sürme.

## Tarayıcı

Script her zaman kullanıcının oturumlu profilini kullanır; temiz/yönetilen tarayıcı açmaz:

| Ortam | Tarayıcı |
|---|---|
| Remote container (`~/.local/bin/gbrowser` var) | `gbrowser` paylaşımlı Chromium'u (CDP `:9222`); kapalıysa script başlatır |
| Mac | Kullanıcının kendi Chrome'u, tarayıcı relay'i üzerinden |

- Mac'te relay eklentisi bağlı değilse script durur: kullanıcıdan Chrome'da eklentiyi bağlamasını iste, başka tarayıcıya geçme.
- Remote'ta Gemini girişi düşmüşse `gbrowser login-url` çıktısını kullanıcıya ver; girişi kullanıcı yapar.

## Kullanım

JS eval hücresinde (kernel sıfırlanırsa yeniden import et):

```js
const G = (await import("${CLAUDE_SKILL_DIR}/scripts/gemini.js?" + Date.now())).install(browser);
const answer = await G.ask("<soru>", { log: display });                 // metin cevap
const file = await G.generate("<tarif>", "/abs/out.png", { log: display }); // görsel; .jpg dönebilir
await G.close();                                                         // iş bitince
```

| Fonksiyon | İş |
|---|---|
| `ask(prompt)` | Gönderir, en yeni cevabın bitmesini bekler, metnini döner |
| `generate(prompt, out)` | Görsel aracını seçer, gönderir, bekler, doğrulanmış indirir; dönen yolu kullan |
| `newChat()` | Agent sekmesinde yeni sohbet açar |
| `attach([abs paths])` | Referans görselleri composer'a ekler |
| `close()` | Agent'ın Gemini sekmesini kapatır |
| `shot(path)` | Sekmenin ekran görüntüsü (teşhis) |

## Kurallar

- Her `ask`/`generate` ayrı eval hücresinde, timeout ≥ 900 sn. Oturum sabitlerini (çıktı dizini, stil tarifi) dosyada tut; hücre kesilince global'ler silinir.
- Agent kendi sekmesinde çalışır (`pageTag`, varsayılan `agent-gemini`); kullanıcının sekmelerine dokunma, pencereyi öne getirme. İş bitince `close()`.
- Görsel üretilmiş sohbette metin sorusundan önce `newChat()`: görsel aracı gönderimden sonra seçili kalır.
- Üretim sürerken yeniden gönderme; ikinci üretim kuyruğa girer.
- Script 4 denemede (`ask` 3) pes ederse kullanıcıya bildir; elle tekrar döngüsü kurma.
- Sohbet bozulup her isteğe metinle cevap verirse: `newChat()` → `attach([...referanslar])` → "in exactly the same style as the attached reference images".

## Görsel prompt'ları

- Görsel aracı açıkken "Create an image:" öneki yazma; yalnız tarif.
- Tutarlı seri: ilk onaylı görseli stil çapası yap, hepsini aynı sohbette üret, her prompt'u "in exactly the same style, palette and lighting as the earlier image in this chat" ile başlat.
- Sahne/arka plan: en-boy oranı, stil, ışık, logo/UI için boş bölgeler, "no text, letters or logo".
- Logo: kelimeyi harf harf yaz, her parçanın rengini belirt; sonuçta yazımı kontrol et.
- Karakter: aynı tarif cümlesini portre ve tam boy için kelimesi kelimesine tekrar kullan.
- İkon/obje sayfası: en fazla 6–18 öğe, saf beyaz #FFFFFF zemin, eşit aralıklı ızgara, yazısız, zemin gölgesiz, dolu boyalı objeler. Gemini ızgarayı ve öğe sayısını tutmayabilir; çizdiği ızgaraya göre eşle, eksikleri ayrı istekte iste.
- Marka/oyun adı geçen prompt'lar reddedilir.

## Çıktı

- `generate` önce cevabın önizlemesini (~1024 px) alır, sonra tam boyu indirip 32×32 karşılaştırır; eşleşmezse önizlemeyi tutar. Tam boy JPEG gelir, uzantı `.jpg` olur.
- Arka planda tam boy indirme çoğu kez tetiklenmez; önizleme normal sonuçtur.
- Paylaşılacak/yayınlanacak görsel için kullanıcı onayı al.
