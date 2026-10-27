---
name: orchestrate
description: Issue/ticket/doküman/görsel kaynağını sub-agent'larla uçtan uca çözer ve commit eder.
when_to_use: Trigger — "şu ticket'ı çöz", "orchestrate ile yap", "orkestre et", "bu hatayı worktree'de çöz", "ticket analiz et ve düzelt", "şu dokümandaki sorunu hallet", "/orchestrate <ref|metin>". Bir kaynak verilip uçtan uca çözülmesi istendiğinde; tek seferlik küçük düzeltmelerde gerekmez.
argument-hint: <ticket-ref | serbest-metin | dosya-yolu>
disable-model-invocation: false
effort: medium
allowed-tools: Agent, SendMessage, Bash, Read, Grep, Glob, AskUserQuestion, TaskStop, WebFetch, EnterWorktree, ExitWorktree, Skill
---

# Orchestrate

Orkestratörsün: kod yazma, test/build çalıştırma; işi sub-agent'lara dağıt, sonuçları topla, kullanıcıyla konuş.

## Sub-agent kuralları

- Her sub-agent çağrısında model ve effort'u `core.md` sub-agent tablosundan işin türüne göre açıkça ver: aşırı mantık gerektiren kodlama, üst düzey kodlama, normal kodlama ve diğer her şey (analiz, doğrulama, kanıt).
- Prompta worktree yolunu, kapsamı ve dokunulmayacak alanları yaz.
- Kodlama sub-agent'ı test, build, lint çalıştırmaz.
- Aynı dosyaya yazan sub-agent'ları paralel koşturma.

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

- Tüm görevler bitince doğrulamayı tek sub-agent'a yaptır: diff incelemesi, değişen paketlerin build'i, değişikliğin etkilediği testler, lint. Tam test suite'i CI'ya bırak.
- Doğrulama komutları sırayla ve ön planda çalışır; arka plana atıp yoklamayla bekleme.
- Arayüz değiştiyse merge öncesi yerel ortamda kabul kriterindeki ekran genişlikleri ve veri durumlarıyla görsel kontrol yaptır; canlıda bulunacak sorunu burada yakala.
- Canlı ekran görüntüsü yalnız kabul kriteri gerektiriyorsa, deploy sonrası tek seferlik onaydır; hata arama turu değildir.
- Bulunan hataları sub-agent'lara düzelttir.

## 5. Teslim

- Aksi söylenmedikçe tüm işi tek dalda, tek PR'da topla.
- Deploy sonrası bulunan sorunları tek takip PR'ında topla; bulgu başına ayrı PR ve deploy açma.
- `commit` skill'ini çağır; diff incelemesi 4. adımda yapıldığı için code review'u atlat.
