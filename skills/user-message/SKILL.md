---
name: user-message
description: Acentaya/müşteriye kanal-agnostik mesaj üretir (ticket/email/panel/WhatsApp/SMS/push).
when_to_use: Trigger — "müşteri mesajı yaz", "acentaya mesaj", "müşteriye yaz", "destek talebi yanıtı", "zammad cevap", "ticket reply", "duyuru yaz", "panel duyurusu", "whatsapp mesajı", "sms yaz", "push notification". Stil rehberi `~/Documents/ObsidianVault/user-message-still.md`'den okunur, zed --wait ile onaya sunulur, revize stil dosyasına öğrenim olarak eklenir.
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
  - "E-posta" — Tam şablon + konu satırı
  - "Panel duyurusu" — 1-2 paragraf, in-app
  - "WhatsApp" — 1 paragraf, emoji yok
  - "SMS" — Tek cümle, 160 karakter
  - "Push notification" — Başlık + 1 satır aksiyon

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

E-posta seçildiyse mesajın başına `Konu: <kısa öz>` satırı ekle.

### 5. Onaya sun (zed --wait)

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

### 6. Sonucu yorumla

zed kapandıktan sonra dosya içeriğini oku ve son satıra bak:

- **`Y`, `Yes`, `Onay`, `Tamam`, `Ok`** → Mesaj onaylandı. Kullanıcıya nihai metni göster ve çık. (Skill mesajı **kendisi göndermez** — kullanıcı kanala kendi yapıştırır.)
- **`N`, `No`, `Iptal`, `Cancel`** → İptal. "Mesaj gönderilmedi." de ve çık.
- **Başka herhangi bir metin** → Revize feedback'i. Adım 7'ye geç.

### 7. Revize akışı

Kullanıcı revize verdiğinde:

#### 7a. Mesajı güncelle

Feedback'i yorumla, stil dosyasını **tekrar oku** (güncel kurallar dahil), mesajı yeniden üret. Adım 5'e dön (yeni onay turu).

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

Onaylanmış mesajı tekrar göster, kullanıcıya kanala yapıştırması için hazır metni sun. Skill mesajı doğrudan göndermez (Zammad/WhatsApp/SMS entegrasyonu ayrı skill — kullanıcı isterse `zammad-cli`/`whatsapp` MCP'ye geçer).

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
