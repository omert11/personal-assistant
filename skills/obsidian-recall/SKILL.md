---
name: obsidian-recall
description: Mevcut proje vault'undan rastgele veya filtreli bir Learnings notu okuyup özetler. Spaced repetition tarzı — eski bilgileri unutmamak için. Kullanıcı "obsidian'dan rastgele not", "eski öğrenilenler", "obsidian recall", "geçmişten bir bilgi", "/obsidian-recall" dediğinde tetiklenir. Resmi Obsidian CLI random:read komutunu kullanır.
disable-model-invocation: false
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: [tag-veya-kategori]
---

# Obsidian Recall

Vault'taki Learnings notlarından birini rastgele oku → özetle. Spaced repetition için periyodik kullanım veya bağlama göre filtreleme.

## Önkoşul

- `obsidian` CLI aktif
- `CLAUDE.local.md`'de `Obsidian Folder` tanımlı
- `<vault>/<folder>/Learnings/` klasörü mevcut

## Akış

### 1. CLI + Folder Doğrula

```bash
obsidian vault info=name 2>&1
```

`CLAUDE.local.md`'den `Obsidian Folder` oku.

### 2. Filtre (Opsiyonel)

`$ARGUMENTS` verilirse → tag/kategori filter:
- `/obsidian-recall api-key` → sadece `#api-key` tag'li notlar
- `/obsidian-recall server` → `#server` tag'li notlar

Filtre var:

```bash
obsidian tag name=<arg> verbose format=json
```

Dönen dosya listesinden rastgele 1 seç (`shuf -n1` veya `awk` random pick).

Filtre yok:

```bash
obsidian random:read folder=<folder>/Learnings
```

### 3. Notu Oku ve Özetle

Okunan içeriği kullanıcıya:

```markdown
# 🧠 Recall — {note-title}

**Konu**: {topic}
**Kategori**: {category-tags}
**Son doğrulanma**: {last_verified}
**Güven**: {confidence}

## Özet (3-4 satır)
{notun 3-4 satır özeti}

## Tam İçerik
{notun ham içeriği veya path: <vault>/<folder>/Learnings/<file>.md}
```

### 4. Aksiyon Önerisi

`AskUserQuestion`:
- header: "Recall"
- question: "Bu not için ne yapalım?"
- options:
  - "Sadece okudum, devam"
  - "last_verified güncelle (hala doğru)"
  - "Notu güncelle (yeni bilgi ekle)"
  - "Sil (artık alakasız)"

Seçime göre:
- **last_verified güncelle**: `obsidian property:set name=last_verified value=$(date +%Y-%m-%d) type=date path=<...>`
- **Güncelle**: `obsidian-writer` agent'ını `MODE: append` ile çağır
- **Sil**: `obsidian delete path=<...>` (kullanıcıdan ayrıca confirm al)

## Kullanım Senaryoları

- **Sabah ritüeli**: Günün başında bir Learnings notunu hatırlat
- **Bağlamsal recall**: `/obsidian-recall server` → bir sunucu notu, deploy öncesi quick check
- **Knowledge sweep**: `/obsidian-recall api-key` → API key rotasyon zamanı kontrolü

## Loop ile Otomatikleştir

`/loop 4h /obsidian-recall` → her 4 saatte bir rastgele not (idle hours dahil). Sessiz mode istenirse `disable-model-invocation: true` flag ile manual-only yap.
