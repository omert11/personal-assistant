---
name: obsidian-audit
description: Obsidian vault sağlık denetimi (kırık [[link]], orphan, deadend, eski Learnings).
when_to_use: Trigger — "obsidian sağlık check", "vault audit", "obsidian denetle", "kırık linkleri bul", "/obsidian-audit". Obsidian CLI gerekli; kapalıysa kullanıcıya açmasını söyler.
disable-model-invocation: false
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
argument-hint: [folder]
---

# Obsidian Audit

Vault sağlık denetimi. Resmi Obsidian CLI komutlarıyla yapısal sorunları ve eskimiş bilgileri tespit eder.

## Önkoşul

- `obsidian` CLI yüklü ve aktif (Settings → General → Advanced → Command line interface)
- Obsidian app açık (CLI app üzerinden çalışır)

## Akış

### 1. CLI Durumu Kontrol

```bash
obsidian vault info=name 2>&1
```

Hata `Command line interface is not enabled` veya `No active vault` dönerse:
- Kullanıcıya "Obsidian app aç + Settings → General → Advanced → Command line interface aktifleştir" mesajı ver ve çık.

### 2. Hedef Klasör Belirle

`$ARGUMENTS` verilirse o klasör, verilmezse:
- `CLAUDE.local.md`'den `Obsidian Folder` oku (Grep)
- Yoksa tüm vault'u (no-folder filter) tara

### 3. Audit Komutları (paralel Bash)

Tek mesajda paralel çağır:

```bash
# Kırık [[wikilink]]'ler
obsidian unresolved verbose format=json

# Bağlantısız notlar (silinebilir candidates)
obsidian orphans format=json

# Outgoing link'i olmayan notlar (terminal node'lar)
obsidian deadends format=json

# Vault istatistik
obsidian vault info=files
obsidian vault info=size
```

### 4. last_verified Audit

Learnings notlarının `last_verified` frontmatter property'sini denetle:

```bash
obsidian files folder=<folder>/Learnings ext=md format=json
```

Her dosya için:

```bash
obsidian property:read name=last_verified path=<folder>/Learnings/<file>.md
```

Tarihi parse et. **30 gün+ eski** veya `last_verified` yoksa "stale" listesine al.

> Not: Bu adım N+1 query üretir; >50 Learnings notu varsa kullanıcıya `AskUserQuestion` ile sor (header: "Audit", options: ["Tamamını tara (yavaş)", "Sadece kırık link/orphan rapor (hızlı)"]).

### 5. Confidence Audit

`confidence: low` olan Learnings notlarını listele — manuel review için.

### 6. Rapor Formatı

```markdown
# Obsidian Audit Raporu — {date}

## Vault Özet
- Klasör: {folder}
- Toplam dosya: {count}
- Toplam boyut: {size}

## Kırık Wikilink'ler ({n} adet)
- `[[broken-note]]` → 3 dosyada referans (Learnings/foo.md, Journal/2026-04-25.md ...)

## Orphan Notlar ({n} adet)
- `Learnings/old-deploy.md` — Hiçbir nottan link yok. Sil veya MOC'a ekle.

## Deadend Notlar ({n} adet)
- `Learnings/leaf.md` — Outgoing link yok. İlgili notlara link ekleyebilir misin?

## Stale Learnings (last_verified > 30 gün)
- `Learnings/hetzner.md` — last_verified: 2025-12-01 (145 gün önce)
- `Learnings/aws-rds.md` — last_verified yok

## Düşük Güven (confidence: low)
- `Learnings/elastic-reindex.md`
```

### 7. Aksiyon Önerisi

Rapor sonunda `AskUserQuestion`:
- header: "Aksiyon"
- question: "Hangi sorunla başlayalım?"
- options:
  - "Kırık linkleri düzelt"
  - "Orphan'ları MOC'a ekle"
  - "Stale notları yenile (last_verified güncelle)"
  - "Düşük confidence notları gözden geçir"
  - "Sadece rapor, aksiyon yok"

Seçilirse ilgili dosyaları aç (`obsidian open file=<path>`) veya ilgili agent'ı çağır.

## Argüman

`$ARGUMENTS` ile spesifik folder denetlenir: `/obsidian-audit personal-assistant` → sadece o vault klasörünü tarar.

## Kullanım Senaryoları

- **Periyodik temizlik**: Haftada bir vault sağlığını kontrol et
- **Yeni proje öncesi**: Yeni `/obsidian-init` çalıştırmadan önce eski vault'ları temizle
- **Bilgi taze tut**: 6 aylık API key'lerin hala geçerli olup olmadığını sor (last_verified eskiyse)
