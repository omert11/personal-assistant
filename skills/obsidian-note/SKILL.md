---
name: obsidian-note
description: Mevcut proje Obsidian klasörüne tekil bir not ekler veya mevcut notu günceller. Kullanıcı "bunu obsidian'a not al", "obsidian'a ekle", "obsidian'a yaz", "bunu kaydet", "/obsidian-note" dediğinde tetiklenir. obsidian-writer agent'ını MODE: append ile çağırır, MOC index.md'ye [[wikilink]] ekler.
disable-model-invocation: false
allowed-tools: Task, Read, Grep, Bash
---

# Obsidian Note

Tek seferlik bilgi/özet/öğrenilen kuralı Obsidian vault'a kaydetmek için `obsidian-writer` agent'ını `MODE: append` ile çağırır.

## Önkoşul

`CLAUDE.local.md`'de `Obsidian Folder: <isim>` tanımlı ve `~/Documents/ObsidianVault/<folder>/index.md` mevcut.

Index yoksa `/obsidian-init` önerip dur.

## Akis

1. `CLAUDE.local.md`'den Obsidian Folder oku
2. `~/Documents/ObsidianVault/<folder>/index.md` var mı kontrol et
3. Yoksa kullanıcıya "Önce `/obsidian-init` çalıştır" de ve çık
4. Var ise `$ARGUMENTS` (veya konuşma bağlamından) not içeriğini topla:
   - Açık bağlam yoksa `AskUserQuestion` ile sor (header: "Not", question: "Ne kaydedilsin?")
5. `Task` tool ile `obsidian-writer` çağır:

```
Task(
  description: "Obsidian'a not ekle",
  subagent_type: "obsidian-writer",
  prompt: "MODE: append\nTARGET: ~/Documents/ObsidianVault/<folder>\nPROJECT_NAME: <proje>\ncontent: <toplanan not>\ntopic: <kısa başlık>\ndate: $(date +%Y-%m-%d)"
)
```

6. Yazılan/güncellenen dosyayı kullanıcıya rapor et.

## Argüman

`$ARGUMENTS` verilirse direkt content olarak kullan. Örnek: `/obsidian-note Hetzner SSH key ~/.ssh/hetzner ile baglaniliyor` → topic otomatik üretilir, content komple yazılır.
