---
name: obsidian-init
description: Projeyi analiz edip Obsidian vault içinde MOC + [[wikilink]] yapısıyla proje belleği oluşturan skill. obsidian-initializer agent'ını tetikler (5 alt agent koordine eder - stack-detector, arch-mapper, readme-extractor, recent-activity, obsidian-writer). Kullanıcı "obsidian belleği oluştur", "obsidian init", "obsidian memory", "/obsidian-init" dediğinde tetiklenir.
disable-model-invocation: false
allowed-tools: Task, Read, Bash, Grep
---

# Obsidian Init

Proje belleğini Obsidian vault'a yazmak için `obsidian-initializer` agent'ını çağırır.

## Önkoşul

`CLAUDE.local.md` dosyasında `Obsidian Folder: <isim>` tanımlı olmalı. Yoksa `/project-init` çağırılmalı.

## Akis

1. `CLAUDE.local.md`'de `Obsidian Folder` satırı var mı kontrol et (Grep ile)
2. Yoksa kullanıcıyı bilgilendir, `/project-init` öner, dur
3. `~/Documents/ObsidianVault/<folder>/index.md` var mı kontrol et
   - Var ise ve `$ARGUMENTS` içinde `--force` yoksa: "Bellek zaten var. Üzerine yazmak için `/obsidian-init --force` kullan. Tek not eklemek için `/obsidian-note`." de ve dur
   - `--force` verilirse eski dosyaları silme sorumluluğunu orchestrator'a bırak (agent `-generated.md` suffix ile yazar)
4. Varsa `Task` tool ile `obsidian-initializer` agent'ını çağır:

```
Task(
  description: "Obsidian belleği oluştur",
  subagent_type: "obsidian-initializer",
  prompt: "Bu proje için Obsidian vault'a MOC + [[wikilink]] yapısıyla proje belleği oluştur. CWD: $(pwd). CLAUDE.local.md'den Obsidian Folder'ı oku, vault ~/Documents/ObsidianVault altında <folder> hedef klasörünü kullan. 5 alt agent'ı (stack-detector, arch-mapper, readme-extractor, recent-activity, obsidian-writer) paralel koordine et."
)
```

4. Agent bitince kullanıcıya yazılan dosyaların listesini göster.

## Argüman

`$ARGUMENTS` verilirse (örn. `/obsidian-init --force`), orchestrator'a ilet. `--force` verilirse mevcut dosyalar üzerine yazılır.
