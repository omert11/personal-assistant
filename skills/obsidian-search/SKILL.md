---
name: obsidian-search
description: Vault'ta bilgi arar — ana agent doğrudan tarar, bulguları sentezleyip kaynaklarıyla sunar.
when_to_use: Trigger — "obsidian'da ara", "vault'ta bul", "X hakkında ne biliyoruz", "Y sorununu nasıl çözmüştük", "/obsidian-search". Ayrıca iş akışında araştırma/doğrulama/karar gerektiren her an. Subagent devri YOK.
disable-model-invocation: false
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
argument-hint: [arama-sorgusu]
---

# Obsidian Search

- Aramayı ana agent kendisi yapar; subagent'a devretme.
- Salt-okur: vault'a yazma; yazma `obsidian-write` işi.

## Vault Yapısı

```
~/Documents/ObsidianVault/
├── <alan>/     # Genel bilgi: django/ rust/ flight/ hotel/ tour/ payment/ frontend/ mobile/ diji-tech/ personal/
├── <proje>/    # Proje-spesifik: <proje>/<modül>/<konu>.md (en fazla 3 seviye)
└── docs/       # Dış kaynak API referansları (obsidian-doc-source üretir; docs/index.md, docs/<source>/index.md)
```

- `docs/`'u genel aramadan hariç tut; yalnız dış kaynak/API dokümanı istenince ayrıca ara.
- Hem genel alan (provider/framework davranışı) hem proje klasörüne (projenin davranışı) bak.

## Akış

### 1. Terimler

Niyet: `$ARGUMENTS` veya kullanıcının son mesajı. 3-6 terim çıkar, her birinin TR + EN karşılığını listele:

| Sorgu kavramı | Denenecek terimler |
|---|---|
| performans | `performans`, `performance`, `cache`, `render`, `N+1`, `slow` |
| ödeme | `ödeme`, `payment`, `3ds`, `hash`, `pos` |
| ana sayfa | `anasayfa`, `ana sayfa`, `homepage`, `home` |
| yetki | `yetki`, `permission`, `role`, `auth` |

Özel adları ayrı terim yap: provider (`biletbank`, `hotelbeds`), teknoloji (`alpine`, `ckeditor`), hata kodu, fonksiyon/ayar adı.

### 2. Yol tahmini

```
~/Documents/ObsidianVault/{django,rust,flight,hotel,tour,payment,frontend,mobile,diji-tech,personal}/*.md
~/Documents/ObsidianVault/<proje>/**/*.md
```

Sorguyla eşleşen dosya adı varsa doğrudan 3. adıma geç.

### 3. İçerik taraması — ana yöntem

Vault'ta (docs HARİÇ) tüm terimler için içerikte ara (büyük/küçük harf duyarsız, yalnız `.md`).

Tam okumadan önce alaka ölç: dosyanın başlık haritası, terimin bağlamlı eşleşmeleri (2 satır önce / 4 satır sonra).

### 4. Oku ve sentezle

- En alakalı 1-3 dosyayı tam oku; eşleşme/dosya adı listesi cevap değil.
- Birden çok dosyayı birleştir; çelişkiyi belirt. Genel + proje dosyası varsa ilişkiyi kur ("provider şöyle davranır → proje şöyle karşılar").

### 5. Sun

```markdown
## <sorgunun kısa ifadesi>

<Sentezlenmiş cevap. Somut: kod yolu, parametre, limit değeri, karar.
Birden çok kaynak varsa birleşik anlatım, çelişki varsa işaretli.>

### Kaynaklar
- [[flight/biletbank]] — neden ilgili (tek satır)
- [[vesentur-web/flight/pricing]] — ...
```

Sonuç yoksa sessizce geçme, raporla:

```markdown
Vault'ta bu konuda kayıt yok. Denenen terimler: `<t1>`, `<t2>`, `<t3>`.
İş bitince `obsidian-write` ile yazılmalı.
```

### 6. Aksiyon (opsiyonel)

Bilgi eksik/yanlışsa soru aracıyla sor; onaylanırsa `obsidian-write`'ı tetikle.

## İlişkili

- `obsidian-write` — yazma
- `obsidian-doc-source` — `docs/` üretimi
