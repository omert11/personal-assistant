---
name: obsidian-write
description: Bilgi/kararı Obsidian vault'a yazar — self-check, konumlandırma, saf gerçek formatı.
when_to_use: Trigger — "obsidian'a yaz", "bunu kaydet", "vault'a ekle", "bu bilgiyi not al", "/obsidian-write". Oturumda kalıcı bilgi/karar doğduğunda; commit skill'in Obsidian sorusu da buraya yönlendirir. Ana agent yazar, subagent devri YOK.
disable-model-invocation: false
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
argument-hint: [yazılacak-bilgi]
---

# Obsidian Write

Dosyaları ana agent kendisi yazar; subagent'a devretme.

## Vault Yapısı

```
~/Documents/ObsidianVault/
├── docs/       # Dış kaynak dokümantasyonu — yalnız obsidian-doc-source yazar
├── <proje>/    # Proje-spesifik: <proje>/<modül>/<konu>.md
└── <alan>/     # Genel bilgi: django/ rust/ flight/ hotel/ tour/ payment/ frontend/ mobile/ diji-tech/ personal/
```

- En fazla 3 seviye (`b2b-dmc/flight/search/brand.md`); daha derin gerekiyorsa konuyu yeniden böl.
- `index.md` / MOC oluşturma (tek istisna `docs/`, `obsidian-doc-source` üretir).

## Ne Yazılır

Yalnız:
1. **Bilgi** — sistem/araç/servis gerçekte nasıl çalışıyor; erişim bilgisi (credential/sunucu/endpoint) dahil.
2. **Karar** — ne yapılacağına dair kalıcı hüküm.

- Bug'ın kendisini değil nihai öğretisini yaz: "Akbank hash açığı vardı, kapatıldı" değil → "Ödemenin kullanıcı tarafından geldiği `HashParamsVal` ile doğrulanmalı".
- Credential tam yazılır (host, port, kullanıcı, şifre, token, key); maskeleme yok.
- Yazılmaz: geçici not, kronoloji/geçmiş, proje yapısı (stack, dizin ağacı, README özeti, commit aktivitesi), oturum özeti.
- Kullanıcı profili / çalışma tercihi / cross-project referans → `~/.claude/memory/`; vault'a değil.
- Şüphedeysen YAZMA.

## Self-Check — ZORUNLU, adım atlanmaz

### 0. Ayrıştırma

1. Kaç bilgi/karar noktası var? Say ve listele.
2. Hiçbiri kalıcı değilse (yalnız bugün geçerli, tek seferlik, oturum özeti, repo/`AGENTS.md`'de zaten yazılı) yazma, çık.

Kalan her nokta için döngüyü ayrı çalıştır; farklı noktaları tek dosyaya tıkma.

### Loop — her nokta için

1. **Genel mi?** "Başka bir repoda çalışırken de arar mıyım?" Evet → genel alan klasörü; hayır → proje klasörü.
2. **Alt kategori?** Yolu belirle (`payment/kuveytturk.md`, `<proje>/flight/pricing.md`), en fazla 3 seviye. Kategori uyduramıyorsan 3'e dön.
3. **Saf kullanım öğretisi?** Yazılacak cümle budur: olay anlatımı değil, doğrudan kullanılabilir gerçek. Yazamıyorsan yazma.
4. **Zaman/durum ifadesi?** "şu an", "geçici olarak", "PR #x ile", "2026-07'de" temizle. Cümle anlamsızlaşıyorsa yazma.
5. **Vault'ta var mı?** İstisnasız bak: yol tahmini + içerikte ara; eşanlamlı, TR/EN karşılık, üst kategori de dene.
6. **Varsa yeterli mi?**
   - Yeterli → hiçbir şey yazma, döngüyü bitir.
   - Eksik/yanlış → mevcut dosyayı düzelt: yanlış satırı sil, doğrusunu yaz. Yeni dosya açma, "güncelleme" bölümü ekleme.
   - Çelişiyor → doğrusunu doğrula; emin değilsen soru aracıyla sor. İkisini yan yana bırakma.
7. **Varsa: iş başında neden bulunamadı?** Bulunamadıysa kullanıcıya bildir: "Bu bilgiyi `<şu terimle>` aratsaydım bulurdum."
8. **Yoksa: başka dosyaya mı ait?** Aynı konuyu taşıyan mevcut dosya varsa oraya madde ekle; bilgi başına ayrı dosya açma.
9. **Tekrar var mı?** Aynı bilgi başka yerde varsa ortak üst seviyeye/genel alana taşı, diğerlerini `[[wikilink]]` ile bağla.
10. **6 ay sonra hangi terimle ararım?** Her terim başlıkta, madde metninde, `tags` veya `aliases`'ta geçmeli; geçmeyeni ekle.
11. **Dosya hâlâ saf mı?** Kronolojik log'a dönmüşse, çelişkili veya geçersiz satır varsa yeniden yaz.

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

- Madde madde yaz; paragraf yok.
- Yorum yok ("dikkat edilmesi gereken", "oldukça esnek", "pratikte genelde").
- Kanıt yok (ticket ID, PNR, commit hash, "vaka: ...").
- Tarih başlığı, changelog, hikâye yok; sistemin şu anki davranışını yaz.
- Kod yolu / parametre / limit değeri gibi teknik kesinliği koru.
- Türkçe yaz; kod, API adı, CLI komutu, hata string'i orijinal.

### Frontmatter

Yalnız `tags` + `aliases`; `date`, `last_verified`, `confidence`, `source`, `category` yazma.

- `tags` — dosya yolunda geçmeyen ayırt edici terimler (provider, teknoloji, hata tipi).
- `aliases` — alternatif adlar: TR/EN karşılık, kısaltma, hata mesajı parçası, fonksiyon/alan adı.

### Arama yüzeyi

- Hata mesajının birebir metni (`PageSize max limit is 100`).
- Alan/fonksiyon/ayar adı orijinal (`HashParamsVal`, `CONN_MAX_AGE`).
- Kavramın TR ve EN karşılığı (bir kez).
- Provider/servis adı tam (`YGG (Yanolja Go Global)`).

## Wikilink

Vault kökünden tam yol: `[[flight/biletbank]]`, başlıklı `[[flight/biletbank|Biletbank]]`. Çıplak `[[biletbank]]` yazma.

## Rapor

Yazılan/güncellenen dosya yollarını tek satırda ver. Yazılmadıysa sebebini söyle (`zaten var: <yol>` / `kalıcı değil`).
