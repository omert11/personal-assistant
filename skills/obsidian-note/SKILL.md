---
name: obsidian-note
description: Mevcut proje Obsidian klasörüne tekil bir not ekler veya mevcut notu günceller. Kullanıcı "bunu obsidian'a not al", "obsidian'a ekle", "obsidian'a yaz", "bunu kaydet", "/obsidian-note" dediğinde tetiklenir. obsidian-writer agent'ını MODE: append ile çağırır, MOC index.md'ye [[wikilink]] ekler. Frontmatter'a category + confidence + source + last_verified ekler.
disable-model-invocation: false
allowed-tools: Task, Read, Grep, Bash, AskUserQuestion
---

# Obsidian Note

Tek seferlik bilgi/özet/öğrenilen kuralı Obsidian vault'a kaydetmek için `obsidian-writer` agent'ını `MODE: append` ile çağırır. Resmi Obsidian CLI (`obsidian` komutu) açıksa onu kullanır, kapalıysa filesystem fallback'ine geçer.

## Önkoşul

`CLAUDE.local.md`'de `Obsidian Folder: <isim>` tanımlı ve `~/Documents/ObsidianVault/<folder>/index.md` mevcut.

Index yoksa `/obsidian-init` önerip dur.

## Akis

1. `CLAUDE.local.md`'den `Obsidian Folder` oku (Grep)
2. `~/Documents/ObsidianVault/<folder>/index.md` var mı kontrol et (Bash `test -f`)
3. Yoksa kullanıcıya "Önce `/obsidian-init` çalıştır" de ve çık
4. Obsidian CLI durumu: `obsidian vault info=name 2>&1` çalıştır. Hata varsa filesystem fallback bilgisini agent'a ilet
5. `$ARGUMENTS` (veya konuşma bağlamından) not içeriğini topla:
   - Açık bağlam yoksa `AskUserQuestion` ile sor (header: "Not", question: "Ne kaydedilsin?")
6. **Kategori tahmin et** (içerikten):
   - `api-key`: "API key", "token", "secret", "password", "credential" geçiyorsa
   - `server`: "SSH", "host", "port", "IP", "VPS" geçiyorsa
   - `decision`: "karar verdik", "seçtik", "X yerine Y kullanıyoruz" geçiyorsa
   - `bug`: "bilinen sorun", "workaround", "bug" geçiyorsa
   - `command`: shell komutu / `bash` / `python -m` paterni varsa
   - `pattern`: kod pattern'i, naming, structure ile ilgiliyse
   - Belirsizse `AskUserQuestion` (header: "Kategori", options: yukarıdaki 6 + "Diğer")
7. `Task` tool ile `obsidian-writer` çağır:

```
Task(
  description: "Obsidian'a not ekle",
  subagent_type: "obsidian-writer",
  prompt: "MODE: append
TARGET: ~/Documents/ObsidianVault/<folder>
PROJECT_NAME: <proje>
content: <toplanan not>
topic: <kısa başlık (kebab-case'e çevrilebilir)>
category: <api-key|server|decision|bug|command|pattern|deprecated>
confidence: <high|medium|low>
source: <kullanıcı paylaşımı | deneme | docs URL ...>
date: $(date +%Y-%m-%d)"
)
```

8. Yazılan/güncellenen dosyayı kullanıcıya rapor et (path + frontmatter özet).

## Argüman

`$ARGUMENTS` verilirse direkt content olarak kullan. Örnek: `/obsidian-note Hetzner SSH key ~/.ssh/hetzner ile baglaniliyor` → topic otomatik üretilir, kategori `server` tahmin edilir, content komple yazılır.

## CLI Aktif Değilse

Obsidian app kapalı veya CLI disabled ise `obsidian-writer` Bash + `Read/Write/Edit/Glob/Grep` ile aynı işi yapar — fonksiyonalite kaybı yok, sadece BM25 search yerine `Grep` kullanır.
