---
name: user-message
description: Acentaya/müşteriye kanal-agnostik mesaj üretir (ticket/email/panel/WhatsApp/SMS/push).
when_to_use: Trigger — "müşteri mesajı yaz", "acentaya mesaj", "müşteriye yaz", "destek talebi yanıtı", "plane yorumu", "issue cevabı", "duyuru yaz", "panel duyurusu", "whatsapp mesajı", "sms yaz", "push notification". Stil rehberi `~/Documents/ObsidianVault/user-message-still.md`'den okunur. E-posta kanalı zengin HTML (vurgulu tablo) üretip sistem varsayılan programıyla açar; diğer kanallar zed --wait ile onaya sunulur. Revize stil dosyasına öğrenim olarak eklenir.
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
disable-model-invocation: false
---

# User Message

Müşteri/acenta tarafına mesaj üretir. Stil rehberi `~/Documents/ObsidianVault/user-message-still.md` — **her çalıştırmada önce bu dosya okunur**, asla bellekten yazılmaz.

## Önkoşul

- `~/Documents/ObsidianVault/user-message-still.md` mevcut olmalı. Yoksa kullanıcıya bildirip dur.
- `zed` CLI sistemde kurulu olmalı (onay akışı için).

## Akış

### 1. Stil rehberini oku

```
Read(file_path: "/Users/omerfarukyigin/Documents/ObsidianVault/user-message-still.md")
```

Dosya yoksa: "Stil rehberi bulunamadı: `~/Documents/ObsidianVault/user-message-still.md`. Önce dosyayı oluştur veya `/personal-assistant:extension-builder` ile skill'i yeniden kur." de ve çık.

### 2. Kanalı belirle

`$ARGUMENTS` veya konuşma bağlamında kanal belirtilmemişse `AskUserQuestion`:

- header: "Kanal"
- question: "Mesaj hangi kanala gidecek?"
- options:
  - "Destek talebi yanıtı" — Tam şablon, `Merhaba,` başlangıç
  - "E-posta" — Tam şablon + konu satırı; **zengin HTML** çıktısı (tablo/vurgu), bkz. Adım 5-E
  - "Panel duyurusu" — 1-2 paragraf, in-app
  - "WhatsApp" — 1 paragraf, emoji yok
  - "SMS" — Tek cümle, 160 karakter
  - "Push notification" — Başlık + 1 satır aksiyon

> **E-posta özel davranışı**: E-posta seçilirse mesaj düz metin yerine **zengin HTML** olarak üretilir (vurgulu tablolar, **kalın**, listeler), sistem varsayılan programıyla (`open`) açılıp görsel olarak incelenir ve onay `AskUserQuestion` ile alınır. Diğer tüm kanallar düz metin + `zed --wait` akışında kalır (Adım 5-T). Kanal seçimine göre Adım 5'te dallan.

### 3. Konu/bağlamı topla

`$ARGUMENTS` doluysa direkt kullan. Boşsa `AskUserQuestion`:

- header: "Konu"
- question: "Mesaj hangi konuda? Sorun/çözüm/sonucu kısaca yaz."
- options: ["Şimdi yazayım"] — kullanıcı "Other" seçip serbest metin verir

### 4. Mesajı üret

Stil rehberindeki kurallara birebir uyarak mesajı yaz. Üretmeden önce mental self-check:

- Teknik terim sızdı mı? (field, endpoint, currency, JSON, API, framework adı)
- Versiyon/deploy detayı var mı?
- İç sistem linki var mı?
- Türkçe karakterler tam mı?
- Kanal uzunluğuna uyuyor mu? (SMS 160, push başlık+1 satır)
- Selamlama/kapanış kanal kuralına uygun mu?
- İmza eklendi mi? (eklenmemeli)
- 1 paragraf veya max 3 bullet mı?
- (E-posta/HTML) Inline CSS mi kullanıldı, `<style>` bloğuna güvenilmedi mi?
- (E-posta/HTML) `<meta charset="utf-8">` var mı, tablo `border-collapse` ile temiz render oluyor mu?

E-posta seçildiyse mesajın başına `Konu: <kısa öz>` satırı ekle (HTML çıktısında `<title>` + üst başlık olarak kullanılır).

### 5. Onaya sun — kanala göre dallan

**Kanal "E-posta" ise → Adım 5-E (zengin HTML + open).** Diğer tüm kanallar → **Adım 5-T (düz metin + zed --wait).**

#### Yabancı Dil Kuralı (ZORUNLU)

Mesaj **Türkçe dışında bir dilde** üretildiyse (İngilizce tedarikçi maili vb.), onay önizlemesi **iki dilli** sunulur:

```
<orijinal yabancı dilde mesaj>

---

(Türkçe)
<mesajın Türkçe çevirisi>
```

- Türkçe bölüm **yalnızca önizleme içindir, gönderilmez** — önizlemede bunu açıkça belirt ("Türkçe çeviri — sadece önizleme, gönderilmeyecek").
- 5-T (zed) dalında: düz metin dosyasında orijinal + `---` ayraç + `(Türkçe)` başlıklı çeviri.
- 5-E (HTML) dalında: orijinal HTML gövdesinin altına `<hr>` + gri arka planlı çeviri bölümü (`<div style="background:#f4f4f4; padding:12px; border-radius:6px">` içinde `(Türkçe çeviri — sadece önizleme, gönderilmeyecek)` etiketi + çeviri).
- Onay sonrası kullanıcıya verilen nihai metin/HTML **sadece orijinal dili** içerir — çeviri bloğu çıkarılır.

#### 5-T. Düz metin onayı (SMS, WhatsApp, Push, Panel, Destek talebi)

Mesajı geçici dosyaya yaz, zed'i bekle-modunda aç, sonucu oku:

```bash
f=/tmp/user-message-$(date +%s).md
cat > "$f" <<'EOF'
<MESAJ_ICERIGI>

---
Onay (Y/N veya revize):
EOF
zed --wait "$f"
cat "$f"
```

**Bash tool ile çağrı**: tek satırda zincirle, `Bash(command: "...", description: "...")`. Heredoc içinde tek tırnak ('EOF') kullan — değişken expansion'ı engelle.

#### 5-E. Zengin HTML onayı (E-posta)

Mesajı **HTML** olarak üret — düz metin değil. Amaç: vurgulu tablolar, **kalın**, listeler gibi zengin metin öğelerinin e-posta gövdesine olduğu gibi yapıştırılabilmesi. `pandoc` gibi dış bağımlılık **kullanma** — HTML'i doğrudan yaz.

HTML kuralları:

- Inline CSS kullan (mail istemcileri `<style>` bloğunu sıklıkla atar). Stiller `style="..."` olarak elementlere gömülür.
- `<table>` için `border-collapse:collapse`, hücrelere `border:1px solid #ddd; padding:8px`. Başlık satırı `<th style="background:#f4f4f4; text-align:left">`.
- Vurgu: `<strong>`, önemli uyarı için renkli kutu (`<div style="background:#fff8e1; border-left:4px solid #f0ad4e; padding:10px">`).
- Türkçe karakterler için `<meta charset="utf-8">` zorunlu.
- İmza ekleme (kanal/sistem ekliyor). Konu satırı `<title>` ve gövde başında `<p><strong>Konu:</strong> ...</p>` olarak yer alır.
- Stil rehberindeki dil/ton kuralları aynen geçerli — sadece sunum HTML.

Geçici dosyaya yaz ve **sistem varsayılan programıyla** aç:

```bash
f=/tmp/user-message-$(date +%s).html
cat > "$f" <<'EOF'
<!DOCTYPE html>
<html lang="tr"><head><meta charset="utf-8"><title>KONU</title></head>
<body style="font-family:-apple-system,Segoe UI,Arial,sans-serif; line-height:1.5; color:#222; max-width:680px; margin:24px auto; padding:0 16px">
<MESAJ_HTML_ICERIGI>
</body></html>
EOF
open "$f"
echo "$f"
```

`open "$f"` dosyayı macOS varsayılan programında (genelde tarayıcı) açar — kullanıcı zengin render'ı görsel olarak inceler.

### 6. Sonucu yorumla

**Adım 5-T (zed) sonrası**: zed kapandıktan sonra dosya içeriğini oku ve son satıra bak:

- **`Y`, `Yes`, `Onay`, `Tamam`, `Ok`** → Mesaj onaylandı. Kullanıcıya nihai metni göster ve çık. (Skill mesajı **kendisi göndermez** — kullanıcı kanala kendi yapıştırır.)
- **`N`, `No`, `Iptal`, `Cancel`** → İptal. "Mesaj gönderilmedi." de ve çık.
- **Başka herhangi bir metin** → Revize feedback'i. Adım 7'ye geç.

**Adım 5-E (HTML/open) sonrası**: `open` ile dosya açıldıktan sonra onayı `AskUserQuestion` ile al (zed kullanılmaz — HTML render edilmiş halde tarayıcıda görünür):

- header: "Onay"
- question: "E-posta önizlemesi varsayılan programda açıldı. Nasıl devam edeyim?"
- options:
  - "Onayla" — Metin hazır, kullanıcı e-posta gövdesine yapıştırır
  - "Revize et" — Değişiklik gerekiyor (kullanıcı "Other" ile feedback'i yazar)
  - "İptal" — Mesaj gönderilmesin

Sonuca göre: **Onayla** → HTML dosya yolunu + içeriğini kullanıcıya göster, çık. **Revize et** → feedback ile Adım 7'ye geç (HTML yeniden üretilir, tekrar 5-E). **İptal** → "Mesaj gönderilmedi." de ve çık.

### 7. Revize akışı

Kullanıcı revize verdiğinde:

#### 7a. Mesajı güncelle

Feedback'i yorumla, stil dosyasını **tekrar oku** (güncel kurallar dahil), mesajı yeniden üret. Adım 5'e dön — **aynı kanal dalında**: e-posta ise 5-E (HTML yeniden üret + `open` + AskUserQuestion), diğer kanallar ise 5-T (zed --wait).

#### 7b. Stil dosyasına öğrenim ekle (arka plan)

Mesajı yeniden onaya sunmadan **önce** veya **paralel olarak**, revize sebebini stil dosyasına ekle. Bu skill'in kendi öğrenimi — gelecekteki üretimlerde tekrar aynı hatayı yapmamak için.

Append içeriği:

```markdown

### {YYYY-MM-DD} — {revize başlığı (kısa, kebab veya cümle)}

**Bağlam**: {hangi kanal, hangi konu}

**Önceki**:
> {revize öncesi cümle/blok — kısa alıntı}

**Revize**:
> {revize sonrası cümle/blok}

**Sebep / kural**: {kullanıcı feedback'i, çıkarılan ders}
```

**Eklenme yöntemi** — Edit tool ile `## Revize Notları (Skill Tarafından Eklenir)` başlığının altına insert:

```
Read(file_path: "/Users/omerfarukyigin/Documents/ObsidianVault/user-message-still.md")
```

`## Revize Notları (Skill Tarafından Eklenir)` başlığını ve altındaki "Kullanıcı bir mesaj revize ettiğinde..." satırını bul. O bloğun **sonuna** (mevcut son revize notunun altına veya açıklama paragrafının hemen altına) yeni `### {tarih} — {başlık}` bloğunu Edit ile ekle.

> NOT: Stil dosyasının ana bölümlerini değiştirme — sadece "Revize Notları" başlığı altına ekle. Eğer revize feedback'i genel bir kural haline gelmişse (örn. "artık asla X yazma"), kullanıcıya `AskUserQuestion` ile sor: header "Kural", question "Bu kuralı stil rehberinin ana bölümüne taşıyayım mı?", options ["Evet, ana bölüme taşı", "Hayır, revize notu olarak kalsın"]. Onay gelirse ilgili ana başlığa Edit ile ekle.

### 8. Self-check ve çıkış

Onaylanmış mesajı tekrar göster, kullanıcıya kanala yapıştırması için hazır metni sun. E-posta dalında ayrıca HTML dosya yolunu (`/tmp/user-message-*.html`) belirt — kullanıcı dosyayı tekrar açabilir veya gövdeye olduğu gibi kopyalayabilir. Skill mesajı doğrudan göndermez (Plane/WhatsApp/SMS entegrasyonu ayrı skill — kullanıcı isterse `plane-cli`/`whatsapp` MCP'ye geçer).

## Argüman Örnekleri

- `/user-message` → kanalı + konuyu sorar
- `/user-message destek talebi: Cari Hesaptan Öde çeviri hatası giderildi` → kanal "destek talebi", konu metinde
- `/user-message sms: Cari Hesaptan Öde ekranındaki sorun giderildi` → SMS, tek cümle

## Hatırlatma

- **Stil dosyası tek doğruluk kaynağı** — bellekten kural çıkarma, her zaman Read.
- **Onay zorunlu** — kullanıcı `Y` demeden mesaj final değil.
- **Revize = öğrenim** — her revize stil dosyasına ders olarak işlenir.
- **İmza ekleme** — kanal/sistem zaten ekliyor.
- **Türkçe karakterler tam** — ASCII karşılık (s/sh, c/ch, vs.) YASAK.
