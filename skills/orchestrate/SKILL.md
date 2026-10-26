---
name: orchestrate
description: Issue/ticket/doküman/görsel kaynağını sub-agent'larla uçtan uca çözer ve commit eder.
when_to_use: Trigger — "şu ticket'ı çöz", "orchestrate ile yap", "orkestre et", "bu hatayı worktree'de çöz", "ticket analiz et ve düzelt", "şu dokümandaki sorunu hallet", "/orchestrate <ref|metin>". Bir kaynak verilip uçtan uca çözülmesi istendiğinde; tek seferlik küçük düzeltmelerde gerekmez.
argument-hint: <ticket-ref | serbest-metin | dosya-yolu>
disable-model-invocation: false
effort: max
allowed-tools: Agent, SendMessage, Bash, Read, Grep, Glob, AskUserQuestion, TaskStop, WebFetch, EnterWorktree, ExitWorktree, Skill
---

# Orchestrate

Orkestratörsün: kod yazma, test/build çalıştırma; işi sub-agent'lara dağıt, sonuçları topla, kullanıcıyla konuş.

## 1. Kaynak ve analiz

- `AGENTS.md` içinde "## Orchestrate" bölümü varsa oku ve uygula.
- Gerekiyorsa analiz sub-agent'larıyla mevcut durumu ve sorunu kodda doğrulat (salt okuma); kök nedeni bul.

## 2. Netleştirme

- Doğru karar netse kararı al ve uygula; teslim özetinde yaz.
- Yalnız kullanıcı onayı veya kararı kesin gerekiyorsa sor; soruları soru aracıyla tek blokta topla.

## 3. Uygulama

- Worktree aç; tüm iş orada yürür.
- Görevleri sub-agent'lara ver.
- İş bitene kadar ne sen ne sub-agent'lar test, build, lint veya doğrulama çalıştırır; ara kırık durum normal.

## 4. Doğrulama ve düzeltme

- Tüm görevler bitince doğrulamayı sub-agent'a yaptır: diff incelemesi, build/test/lint.
- Bulunan hataları sub-agent'lara düzelttir.

## 5. Teslim

- Aksi söylenmedikçe tüm işi tek dalda, tek PR'da topla.
- `commit` skill'ini çağır.
