---
name: design-brief
description: UI ekranlarının/akışının görüntülerini + yapısal dökümünü toplayıp Claude Design brief'i üretir.
when_to_use: Trigger — "design brief oluştur", "ekranların brief'ini çıkar", "Claude Design için hazırla", "UI dökümü çıkar", "şu akışı belgele", "/design-brief". Bir uygulamanın bir veya birkaç ekranını/akışını görsel + tarafsız yapısal döküm olarak belgeleyip bir tasarım aracına (Claude Design vb.) girdi vermek istendiğinde. Stack/dil/framework bağımsızdır.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, SendUserFile
---

# Design Brief — UI Ekranlarını Yakala + Tarafsız Belgele

Bir uygulamanın **bir veya birkaç ekranını/akışını** görsel olarak yakalar ve her ekranın
**hangi bileşen/veri/etkileşime** sahip olduğunu **tarafsız** belgeler. Çıktı: ekran görüntüleri +
`BRIEF.md` — bir tasarım aracına (Claude Design vb.) girdi olarak verilip iyileştirilmiş tasarım
ürettirmek için. **Dil/framework/ortam bağımsızdır** (web, mobil-web, PWA, masaüstü, herhangi stack).

> **Bu skill tasarım ÖNERMEZ — mevcut durumu belgeler.** "Şu kötü / şöyle olmalı" yorumu
> yalnızca kullanıcı açıkça "bilinen sorunları da ekle" derse girer; varsayılan tarafsızdır.

---

## Adım 0 — Kapsamı netleştir (AskUserQuestion)

Kullanıcının verdiği bağlamdan çıkaramadığın her boşluğu **tek `AskUserQuestion` bloğunda** sor
(max 4 soru). Netleştirilecekler:

1. **Hedef ne / nasıl erişilir** — Yakalanacak uygulama bir URL mi (web/local dev server),
   çalışan bir uygulama mı, yoksa kullanıcı görselleri kendisi mi sağlayacak? Local ise
   başlatma komutu/portu var mı?
2. **Hangi ekran(lar)/akış** — Tek ekran mı, çok ekranlı bir akış mı (liste → filtre → detay gibi)?
   Kullanıcı ekranları say(dır) — her biri brief'te ayrı bölüm olur.
3. **Platform/viewport** — Mobil (örn. 390×844), masaüstü, tablet? Capture viewport'u buna göre ayarlanır.
4. **Amaç/ton** — (a) Sadece mevcut durumu tarafsız belgele *(varsayılan)*, (b) bilinen UX
   sorunlarını/eksikleri da ekle.

> Bağlamdan netse sorma; eksik olanı sor. "Stack ne?" diye sorma — skill stack-agnostik, gerek yok.

---

## Adım 1 — Çalışma klasörünü hazırla

```bash
SLUG="<kebab-case-kısa-konu>"          # örn. "tour-search-flow", "checkout"
EVID="/tmp/design-brief-$SLUG"
mkdir -p "$EVID"
```

Tüm görseller ve `BRIEF.md` buraya yazılır (repo dışı, `/tmp`).

---

## Adım 2 — Ekranları yakala (ortama göre otomatik)

Hedefin tipine göre **otomatik** seç — hiçbir stack'e bağlanma:

| Hedef tipi | Yöntem |
|---|---|
| **URL (web / local dev server)** | `playwright-cli` skill. Gerekirse viewport ayarla (`resize <w> <h>`), akışı adım adım sür (`open` → `snapshot` → `click`/`fill` → `screenshot`). Her ekran için `screenshot --filename "$EVID/NN-<ekran>.png"`. |
| **Local uygulama (önce başlatılmalı)** | Kullanıcının verdiği başlatma komutunu **arka planda** (`run_in_background: true`) çalıştır, port'u bekle, sonra `playwright-cli` ile bağlan. Bitince **uygulamayı durdur** (orphan bırakma). |
| **Çalışan ama otomatikleştirilemeyen / native / masaüstü app** | Kullanıcıdan her ekranın **görüntüsünü iste** (paste/dosya), `$EVID/`'ye kopyala. Capture yapma. |
| **Kullanıcı görselleri sağladı** | Doğrudan `$EVID/`'ye al, `Read` ile her birini incele. |

**Akış yakalama prensibi** (çok ekranlı): kullanıcının saydığı her ekrana **gerçek kullanıcı
akışıyla** ulaş (ana ekran → etkileşim → hedef ekran). Her anlamlı durumu ayrı dosyaya çek
(örn. bir panelin kapalı + açık hali ayrı). Dosyaları `NN-<ekran>.png` sıralı adlandır.

> **Her ekran görüntüsünü `Read` ile incele** — sadece çekmek yetmez; brief'teki yapısal döküm
> için içeriği (bileşenler, metin, veri alanları, ikonlar, butonlar) gözlemlemen gerekir.
> `playwright-cli snapshot` çıktısı (a11y ağacı) ref/etiket/metin verir — döküm için birincil kaynak.

> **Capture sonrası temizlik (ZORUNLU):** Local app başlattıysan **durdur**
> (`kill $(lsof -ti tcp:$PORT)` vb.), `playwright-cli close` ile tarayıcıyı kapat. İptal/hata
> durumunda da yapılır — orphan process/port bırakma.

---

## Adım 3 — `BRIEF.md` yaz (tarafsız yapısal döküm)

`$EVID/BRIEF.md` oluştur. Yapı (uyarlanır — ekran sayısına göre):

```markdown
# Design Brief — <Uygulama/Akış Adı> (Mevcut Durum)

> Amaç: Aşağıdaki ekranların MEVCUT yapısını ve içerdiği veri/özellikleri tarafsız belgeler.
> <Tasarım aracı> bu dökümü + görselleri girdi alarak iyileştirilmiş tasarım üretecek.
> Mevcut durumu anlatır; tasarım önerisi içermez.

**Platform/viewport**: <mobil 390×844 / masaüstü / ...>
**Dil / yerelleştirme**: <TR / çok dilli / ...>
**Görseller**: bu klasörde NN-*.png

## Akış Şeması
(çok ekranlıysa ASCII akış: ekran → etkileşim → ekran)

## ① <Ekran adı> — `NN-<ekran>.png`
- Bölüm bölüm: navbar/header, ana içerik, kartlar/listeler, alt bar
- Her bileşen için: gösterdiği VERİ ALANLARI + etkileşimler (buton/link/input/sheet)
- İkonografi (kullanılan ikon adları, varsa)
- NOT: gözlemlenen tarafsız olgular (örn. "kartta X gösterilmiyor, detayda var")

## ② <Ekran adı> — ...
(her ekran için tekrarla)

## Renk & Bileşen Dili
(gözlemlenen: primary renk, kart/zemin, tipografi vurgu, sheet tipleri)

## İkonografi
(tüm ekranlarda görülen ikon envanteri)

## Tasarımcı için Bağlam Notları (tarafsız)
(ekranlar arası tutarsızlık, veri farkı, i18n/uzunluk kısıtı gibi NESNEL notlar)
```

**Tarafsızlık kuralı**: "ne var, hangi veri, nasıl etkileşim" yaz. Estetik/UX yargısı
("kötü", "kalabalık", "iyileştirilmeli") **yazma** — kullanıcı Adım 0'da "bilinen sorunları da
ekle" dediyse ayrı bir **"## Bilinen Sorunlar"** bölümü aç, ana dökümü tarafsız tut.

---

## Adım 4 — Teslim et

```bash
zed "$EVID" 2>/dev/null   # (varsa) klasörü aç
```

`SendUserFile` ile `BRIEF.md` + tüm ekran görüntülerini kullanıcıya gönder (status: normal),
caption'da kısa özet (kaç ekran, hangi akış). Kullanıcıya brief'i bir tasarım aracına girdi
verebileceğini hatırlat.

---

## Akış Özeti

```
0. Kapsamı netleştir (AskUserQuestion): hedef/erişim, ekranlar, platform/viewport, amaç
1. /tmp/design-brief-<slug>/ hazırla
2. Yakala (otomatik): URL→playwright-cli | local→başlat+bağlan+durdur | native/sağlanan→kullanıcı görseli
   — her ekranı Read ile incele, snapshot ile yapı çıkar
3. BRIEF.md yaz — tarafsız yapısal döküm (akış + ekran ekran veri/bileşen/etkileşim)
4. zed ile aç + SendUserFile ile brief + görselleri gönder
```

## Notlar

- **Stack-agnostik**: web, PWA, mobil-web, masaüstü — fark etmez. Kod tabanına bakmak ZORUNLU değil;
  istenirse (örn. bileşen/veri adlarını netleştirmek) `Grep`/`Read` ile doğrulanabilir ama brief
  gözlemlenen UI'ya dayanır, koda değil.
- **Görsel kanıt birincil**: brief'in her bölümü bir ekran görüntüsüne dayanmalı. Çekemediğin
  bir ekranı dökme — kullanıcıdan görsel iste.
- **Capture aracı**: web/URL için `playwright-cli` skill (viewport `resize`, akış `click`/`fill`,
  `snapshot` ile a11y ağacı). Detaylı kullanım o skill'de.
- **Çıktı izolasyonu**: her zaman `/tmp/design-brief-<slug>/` — görseller canlı veri içerebilir,
  repo dışı kalır. Kullanıcı kalıcı isterse taşır.
- **Onay**: kapsam Adım 0'da netleşir; capture + brief üretimi onay beklemeden akar. Yalnızca
  hedefe nasıl erişileceği belirsizse (başlatma komutu, credential) sor.
