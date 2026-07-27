---
name: obsidian-write
description: Bilgi/kararı Obsidian vault'a yazar — self-check, konumlandırma, saf gerçek formatı.
when_to_use: Trigger — "obsidian'a yaz", "bunu kaydet", "vault'a ekle", "bu bilgiyi not al", "/obsidian-write". Oturumda kalıcı bilgi/karar doğduğunda; commit skill S5 ve UserPromptSubmit kayıt hint'i de buraya yönlendirir. Ana agent yazar, subagent devri YOK.
disable-model-invocation: false
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
argument-hint: [yazılacak-bilgi]
---

# Obsidian Write

Vault'a bilgi/karar yazar. Kural: `~/.claude/rules/obsidian.md` — bu skill onun yazma tarafının uygulama adımlarıdır.

## Yazma Modeli — Subagent YOK

Dosyaları **ana agent kendisi yazar** (`Write`/`Edit`). Hiçbir subagent'a devredilmez.

Sebep: devirde bilgi prompt'a serialize edilir, teknik kesinlik (parametre adı, limit değeri, hata metni) yolda kaybolur ve devralan taraf kaybı fark edemez. Kaynağı gören agent yazmalı.

## Ne Yazılır

Yalnız iki tip:

1. **Bilgi** — sistem/araç/servis gerçekte nasıl çalışıyor; erişim bilgisi (credential/sunucu/endpoint) dahil
2. **Karar** — ne yapılacağına dair verilmiş kalıcı hüküm

Bug'ın kendisi yazılmaz, **nihai öğretiye dönüştürülür**: "Akbank hash açığı vardı, kapatıldı" değil → "Ödemenin kullanıcı tarafından geldiği `HashParamsVal` ile doğrulanmalı".

**Credential tam yazılır** — host, port, kullanıcı, şifre, token, key açıkça. Vault lokal dosya sistemidir, maskeleme yapılmaz.

Şüphedeysen **YAZMA**.

## Self-Check — ZORUNLU

Sırayla sor, cevabı kendine ver. Adım atlanmaz.

### 0. Ayrıştırma

**0.1 — Kaç bilgi/karar noktası var?**
Bir iş birden fazla nokta üretebilir. Say ve listele.

**0.2 — Hiçbiri kalıcı değilse dur.**
Yalnız bugün geçerliyse, tek seferlik durumsa, oturum özetiyse veya repo/`CLAUDE.md`'de zaten yazılıysa **yazma, çık**.

**Kalan her nokta için aşağıdaki döngüyü ayrı ayrı çalıştır.** Farklı noktaları tek dosyaya tıkma.

### Loop — her nokta için

**1. Genel bilgi mi?**
Ölçüt: *"Bu bilgiyi başka bir repoda çalışırken de arar mıyım?"* → Evet ise genel alan klasörü (`flight/`, `hotel/`, `tour/`, `payment/`, `django/`, `frontend/`, `mobile/`, `diji-tech/`). Hayır ise proje klasörü.

**2. Sub kategorileri var mı?**
Yolu belirler: `payment/kuveytturk.md`, `<proje>/flight/pricing.md`. En fazla 3 seviye.
Kategori uyduramıyorsan bilgi yanlış tanımlanmış — 3'e dön.

**3. Saf kullanım öğretisi nedir?**
Vault'a yazılacak cümle budur. Olay anlatımı değil, doğrudan kullanılabilir gerçek.
Öğretiyi yazamıyorsan bilgi olgunlaşmamış — **yazma**.

**4. Zaman/duruma bağlı ifade kaldı mı?**
"şu an", "geçici olarak", "PR #x ile", "2026-07'de" temizlenir. Temizleyince cümle anlamsızlaşıyorsa bilgi kalıcı değildir — **yazma**.

**5. Vault'ta bu bilgi var mı?**
**İstisnasız bak** — `Glob` ile yol tahmini + `Grep` ile içerik. Atlanamaz.
Tek terim yetmez: eşanlamlı, TR/EN karşılık, üst kategori de denenir.

**6. Varsa yeterli mi?**
- Yeterliyse → **hiçbir şey yazma**, döngüyü bitir
- Eksik/yanlışsa → mevcut dosyayı **düzelt**: yanlış satır silinir, doğrusu yazılır. Yeni dosya açma, alta "güncelleme" bölümü ekleme
- Çelişiyorsa → hangisi doğru doğrula; emin değilsen `AskUserQuestion` ile sor, ikisini yan yana bırakma

**7. Varsa: iş başında neden bulamadın?**
Bilgi vault'ta olduğu hâlde iş başında bulunamadıysa arama stratejisi hatalıdır. **Kullanıcıya bildir**: "Bu bilgiyi `<şu terimle>` aratsaydım bulurdum." Bulunduysa bildirime gerek yok.

**8. Yoksa: başka dosyaya mı ait?**
Yeni dosya açmadan önce aynı konuyu taşıyan mevcut dosya var mı bak. Varsa oraya madde eklenir — her bilgi için ayrı dosya vault'u parçalar.

**9. Tekrar var mı?**
Aynı bilgi başka yerde duruyorsa ortak olan üst seviyeye/genel alana taşınır, diğerleri `[[wikilink]]` ile bağlanır.

**10. 6 ay sonra hangi terimle ararım?**
Terimleri say. Hepsi dosyada geçiyor mu — başlıkta, madde metninde, `tags`'te veya `aliases`'ta? Geçmeyeni ekle.

**11. Yazdıktan sonra dosya hâlâ saf mı?**
Kronolojik log'a dönüşmüşse, çelişkili madde varsa veya geçersiz satır kaldıysa **yeniden yaz**.

## Dosya Formatı

```md
---
tags: [biletbank, soap, pricing, update_items]
aliases: [Biletbank fiyat, price-check sync, ReadShoppingFile]
---

# Biletbank (Uçuş SOAP)

## Fiyat Breakdown Her Event'te Değişir

- Search — brand fare yapısına göre `Taxes=0` gelebilir
- Allocate — `update_items` ile item bazında onaylı fiyat döner

## İlgili

- [[vesentur-web/flight/pricing]]
```

Kurallar:

- **Madde madde yaz** — paragraf anlatımı değil
- **Yorum yok** — "dikkat edilmesi gereken", "oldukça esnek", "pratikte genelde" yazılmaz
- **Kanıt yok** — ticket ID, PNR, commit hash, "vaka: ..." yazılmaz
- **Hikâye yok** — sistem **şu an nasıl davranıyor** o yazılır
- Kod yolu / parametre / limit değeri gibi teknik kesinlik korunur
- Türkçe yaz; kod, API adı, CLI komutu, hata string'i orijinal
- `index.md` / MOC oluşturulmaz

### Frontmatter — Yalnız Arama İçin

`tags` + `aliases` yazılır, başka alan yazılmaz.

- **`tags`** — dosya yolunda **geçmeyen** ayırt edici terimler: provider adı, teknoloji, hata tipi. Yolda olanı tekrarlama
- **`aliases`** — alternatif adlar: TR/EN karşılık, kısaltma, hata mesajı parçası, fonksiyon/alan adı

**Yazılmaz**: `date`, `last_verified`, `confidence`, `source`, `category` — bayatlar, aramaya katkı vermez.

### Arama Yüzeyini Genişlet

- Hata mesajının **birebir metni** yazılır (`PageSize max limit is 100`)
- Alan/fonksiyon/ayar adı orijinal (`HashParamsVal`, `CONN_MAX_AGE`)
- Kavramın hem TR hem EN karşılığı geçsin (bir kez yeter)
- Provider/servis adı tam (`YGG (Yanolja Go Global)`)

## Wikilink

Vault-kökünden tam yol: `[[flight/biletbank]]`, başlıklı: `[[flight/biletbank|Biletbank]]`.
Çıplak `[[biletbank]]` yazma — yanlış dosyaya çözülür.

## Rapor

Yazılan/güncellenen dosya yollarını tek satırda ver. Hiçbir şey yazılmadıysa sebebini söyle (`zaten var: <yol>` / `kalıcı değil`).
