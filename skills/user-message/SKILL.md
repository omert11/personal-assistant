---
name: user-message
description: Acentaya/müşteriye kanal-agnostik mesaj üretir (ticket/email/panel/WhatsApp/SMS/push).
when_to_use: Trigger — "müşteri mesajı yaz", "acentaya mesaj", "müşteriye yaz", "destek talebi yanıtı", "plane yorumu", "issue cevabı", "duyuru yaz", "panel duyurusu", "whatsapp mesajı", "sms yaz", "push notification". Stil rehberi `~/Documents/ObsidianVault/user-message-still.md`'den okunur. E-posta kanalı zengin HTML (vurgulu tablo) üretip sistem varsayılan programıyla açar; diğer kanallar zed --wait ile onaya sunulur. Revize stil dosyasına öğrenim olarak eklenir.
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
disable-model-invocation: false
---

# User Message

Önkoşul: `zed` CLI kurulu (5-T onayı için).

## 1. Stil rehberini oku

Her çalıştırmada önce oku; kural bellekten çıkarılmaz, tek doğruluk kaynağı bu dosya:

```
/Users/omerfarukyigin/Documents/ObsidianVault/user-message-still.md
```

Yoksa: "Stil rehberi bulunamadı: `~/Documents/ObsidianVault/user-message-still.md`." de ve dur.

## 2. Kanalı belirle

`$ARGUMENTS` veya konuşmada kanal yoksa soru aracıyla sor:

- header: "Kanal"
- question: "Mesaj hangi kanala gidecek?"
- options:
  - "Destek talebi yanıtı" — Tam şablon, `Merhaba,` başlangıç
  - "E-posta" — Tam şablon + konu satırı; zengin HTML (5-E)
  - "Panel duyurusu" — 1-2 paragraf, in-app
  - "WhatsApp" — 1 paragraf, emoji yok
  - "SMS" — Tek cümle, 160 karakter
  - "Push notification" — Başlık + 1 satır aksiyon

## 3. Konu/bağlamı topla

`$ARGUMENTS` doluysa kullan. Boşsa soru aracıyla sor:

- header: "Konu"
- question: "Mesaj hangi konuda? Sorun/çözüm/sonucu kısaca yaz."
- options: ["Şimdi yazayım"] — kullanıcı "Other" ile serbest metin verir

Argüman biçimi:
- `/user-message` → kanal + konu sorulur
- `/user-message destek talebi: Cari Hesaptan Öde çeviri hatası giderildi` → kanal "destek talebi", konu metinde
- `/user-message sms: Cari Hesaptan Öde ekranındaki sorun giderildi` → SMS, tek cümle

## 4. Mesajı üret

- Stil rehberine birebir uy.
- İmza ekleme (kanal/sistem ekliyor).
- Türkçe karakterler tam; ASCII karşılık (s/sh, c/ch vs.) YASAK.
- E-posta: başa `Konu: <kısa öz>` satırı (HTML'de `<title>` + üst başlık).

## 5. Onaya sun

E-posta → 5-E. Diğer tüm kanallar → 5-T.

### 5-T. Düz metin + zed (SMS, WhatsApp, Push, Panel, Destek talebi)

Tek komutta zincirle; heredoc tek tırnaklı `'EOF'` (expansion yok):

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

### 5-E. Zengin HTML + open (E-posta)

HTML'i doğrudan yaz (`pandoc` vb. dış bağımlılık yok):
- Stiller inline `style="..."` (`<style>` bloğu yok).
- Vurgu `<strong>`, tablo, liste; önemli uyarı kutusu: `<div style="background:#fff8e1; border-left:4px solid #f0ad4e; padding:10px">`.
- `<meta charset="utf-8">` zorunlu.
- Konu: `<title>` + gövde başında `<p><strong>Konu:</strong> ...</p>`.
- Stil rehberinin dil/ton kuralları aynen geçerli.

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

## 6. Sonucu yorumla

Mesaj kullanıcı onayı olmadan final değildir. Skill mesajı göndermez; kullanıcı kanala kendisi yapıştırır (Plane/WhatsApp gönderimi istenirse `plane-cli`/`whatsapp` MCP).

**5-T sonrası** — dosyanın son satırı:
- `Y`, `Yes`, `Onay`, `Tamam`, `Ok` → onay; nihai metni göster, çık.
- `N`, `No`, `Iptal`, `Cancel` → "Mesaj gönderilmedi." de, çık.
- Başka metin → revize feedback'i; Adım 7.

**5-E sonrası** — soru aracıyla sor (zed yok):
- header: "Onay"
- question: "E-posta önizlemesi varsayılan programda açıldı. Nasıl devam edeyim?"
- options:
  - "Onayla" — Metin hazır, kullanıcı e-posta gövdesine yapıştırır
  - "Revize et" — Değişiklik gerekiyor (kullanıcı "Other" ile feedback'i yazar)
  - "İptal" — Mesaj gönderilmesin

Onayla → HTML dosya yolu (`/tmp/user-message-*.html`) + içeriği göster, çık. Revize et → Adım 7. İptal → "Mesaj gönderilmedi." de, çık.

## 7. Revize

### 7a. Mesajı güncelle

Feedback'i yorumla, stil dosyasını tekrar oku, mesajı yeniden üret, aynı kanal dalına dön (e-posta → 5-E, diğer → 5-T).

### 7b. Stil dosyasına kural olarak işle

Her revize stil dosyasına kural olarak yazılır. Dosya yalnız kural listesidir.

1. Dersin bölümünü bul (alıcı tipi, acenta yazılmayacaklar, tedarikçi, kanal, insansı yazım vb.).
2. Mevcut madde kapsıyorsa o maddeyi düzelt; kapsamıyorsa ilgili bölüme yeni madde ekle.
3. Hiçbir bölüme uymuyorsa yeni `## N. {Başlık}` bölümü aç, sonraki bölümleri yeniden numaralandır.
4. Dosyada düzenle.

Kural metni:
- Tek cümle emir/olgu kipi: "Tedarikçiye aksiyon önerme.", "E-posta HTML üretilir."
- Gerekçe yalnız kural tek başına anlaşılmıyorsa, aynı satırda kısa ek.
- Örnek yalnız kalıbı kelimesi kelimesine göstermek gerekiyorsa: tek ❌ / tek ✅.
- Yasak: revize hikâyesi ("kullanıcı şunu istedi"), tarih, bağlam anlatımı, önceki/sonraki karşılaştırması, aynı fikri tekrar eden ikinci cümle.
- Mevcut maddeyle çelişen ders için ikinci madde ekleme; eski maddeyi güncelle, kapsam ayrımı gerekiyorsa tek maddede belirt.

Ders mevcut kuralı geçersiz kılıyorsa (istisna veya geri alma) soru aracıyla sor:
- header: "Kural"
- question: "Bu ders mevcut '{kural}' kuralıyla çelişiyor. Nasıl işleyeyim?"
- options: ["Eski kuralı güncelle", "İstisna olarak ekle", "İşleme"]
