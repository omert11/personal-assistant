---
name: obsidian-search
description: Vault'ta bilgi arar — ana agent doğrudan tarar, bulguları sentezleyip kaynaklarıyla sunar.
when_to_use: Trigger — "obsidian'da ara", "vault'ta bul", "X hakkında ne biliyoruz", "Y sorununu nasıl çözmüştük", "/obsidian-search". Ayrıca iş akışında araştırma/doğrulama/karar gerektiren her an (UserPromptSubmit hint bunu hatırlatır). Subagent devri YOK.
disable-model-invocation: false
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
argument-hint: [arama-sorgusu]
---

# Obsidian Search

Vault'ta bilgi arar, bulunanları okuyup **sentezlenmiş cevap + kaynak listesi** olarak sunar.

Vault kökü: `~/Documents/ObsidianVault/`. Yapı ve yazma kuralları: `~/.claude/rules/obsidian.md`.

## Arama Modeli — Subagent YOK

Aramayı **ana agent kendisi yapar** (`Glob` / `Grep` / `Read` / `obsidian` CLI). Subagent'a devretme.

Sebep: devralan agent bulguyu özetleyip döner, teknik kesinlik (parametre adı, limit değeri, dosya yolu) serileştirmede kaybolur ve kaybı kimse fark etmez. Arayan ile bilgiyi kullanan aynı agent olmalı.

## Vault Yapısı — Nereye Bakılır

```
~/Documents/ObsidianVault/
├── <alan>/          # Genel bilgi: flight/ hotel/ tour/ payment/ django/ frontend/ mobile/ diji-tech/
├── <proje>/         # Proje-spesifik: <proje>/<modül>/<konu>.md
└── docs/            # Dış kaynak API referansları — AYRI aranır (aşağıya bak)
```

**`docs/` her zaman hariç tutulur** — 300+ dosyayla genel aramayı boğar. Yalnız "şu API'nin dokümanı" tipi sorularda ayrıca aranır.

Aranan bilgi hem genel alanda hem proje klasöründe olabilir: proje dosyası kendi davranışını, genel alan dosyası provider/framework davranışını taşır. **İkisine de bak.**

## Akış

### 1. Sorguyu Terimlere Ayır

`$ARGUMENTS` veya kullanıcının son mesajındaki niyet.

Sorgudan 3-6 terim çıkar ve her birinin **TR + EN karşılığını** listele. Türkçe terim çoğu zaman boş döner, İngilizce karşılığı dolu:

| Sorgu kavramı | Denenecek terimler |
|---|---|
| performans | `performans`, `performance`, `cache`, `render`, `N+1`, `slow` |
| ödeme | `ödeme`, `payment`, `3ds`, `hash`, `pos` |
| ana sayfa | `anasayfa`, `ana sayfa`, `homepage`, `home` |
| yetki | `yetki`, `permission`, `role`, `auth` |

Ayrıca sorgudaki **özel adları** ayrı terim yap: provider adı (`biletbank`, `hotelbeds`), teknoloji (`alpine`, `ckeditor`), hata kodu, fonksiyon/ayar adı.

### 2. Yol Tahmini (Glob) — En Ucuz Adım

Dosya adları konu adıdır; çoğu zaman tek `Glob` cevabı verir.

```
Glob: ~/Documents/ObsidianVault/{flight,hotel,tour,payment,django,frontend,mobile,diji-tech}/*.md
Glob: ~/Documents/ObsidianVault/<proje>/**/*.md
```

Listeyi gör, sorguyla eşleşen dosya adı varsa doğrudan **3. adıma atla**.

### 3. İçerik Taraması (Grep) — Ana Yöntem

```bash
# docs HARİÇ, tüm terimler için
grep -ril "<terim>" --include="*.md" ~/Documents/ObsidianVault | grep -v "/docs/"
```

Aday dosya çıkınca **önce başlıklarını** oku — tam okumadan önce alaka ölç:

```bash
grep -n "^#" <dosya>            # başlık haritası
grep -n -B2 -A4 "<terim>" <dosya>   # bağlamlı eşleşme
```

`-B2 -A4` bağlamı, `obsidian search:context`'ten hem daha okunabilir hem daha ucuzdur.

### 4. BM25 (opsiyonel, tamamlayıcı)

Obsidian CLI açıksa kelime köküyle eşleşme yakalar — Grep'in literal eşleşmesinin kaçırdığını bulabilir.

```bash
obsidian vault info=name 2>&1                      # aktif mi
obsidian search query="<tek-terim>" path=<proje> format=json
```

Kurallar:
- **Tek terim** — çok kelimeli sorgu AND'lenir, sık sık `No matches found` döner
- **`path=` şart** — filtresiz sorgu `docs/` dahil 40+ sonuç döndürür, alaka sırası yoktur
- `search:context` **kullanma** — aynı satırı 3-4 kez tekrarlayan ham JSON üretir; `grep -B2 -A4` yerine geçer
- CLI kapalıysa (`No active vault`) atla — Grep her koşulda çalışır

### 5. Oku ve Sentezle

En alakalı **1-3 dosyayı tam oku**. Match listesi cevap değildir.

Birden çok dosya varsa birleştir; çelişki varsa belirt. Genel alan + proje dosyası ikisi de varsa ilişkiyi kur ("provider şöyle davranır → proje bunu şöyle karşılar").

### 6. Sun

```markdown
## <sorgunun kısa ifadesi>

<Sentezlenmiş cevap. Somut: kod yolu, parametre, limit değeri, karar.
Birden çok kaynak varsa birleşik anlatım, çelişki varsa işaretli.>

### Kaynaklar
- [[flight/biletbank]] — neden ilgili (tek satır)
- [[vesentur-web/flight/pricing]] — ...
```

**Hiç bulunamadıysa** bunu bir sonuç olarak raporla — başarısızlık değil, "bu konu henüz yazılmamış" bilgisidir:

```markdown
Vault'ta bu konuda kayıt yok. Denenen terimler: `<t1>`, `<t2>`, `<t3>`.
İş bitince `obsidian-write` ile yazılmalı.
```

### 7. Aksiyon (opsiyonel)

Bulunan bilgi **eksik/yanlış** çıkarsa `AskUserQuestion` ile sor, onaylanırsa `obsidian-write` skill'ini tetikle.

## Kurallar

- **Salt-okur** — bu skill vault'a yazmaz. Yazma `obsidian-write` işidir
- **`docs/` hariç** — açıkça dış kaynak dokümanı istenmedikçe
- **TR + EN çifti** — tek dilde arama eksik sonuç verir
- **Sıfır sonuç bilgidir** — sessizce geçme, raporla
- **Oku, listeleme** — dosya adı listesi cevap değil; en alakalıları açıp sentezle
- **Genel + proje** — biri diğerini tamamlar, ikisine de bak

## İlişkili

- `skills/obsidian-write/SKILL.md` — yazma
- `skills/obsidian-doc-source/SKILL.md` — `docs/` üretimi
- `rules/obsidian.md` — vault mimarisi ve içerik kuralları
