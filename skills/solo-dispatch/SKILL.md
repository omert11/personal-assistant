---
name: solo-dispatch
description: Görevleri Solo'da remote/yerel ajan oturumlarına dağıtır, izler, mesaj iletir, teslimi toplar.
when_to_use: Trigger — "şunu başlat", "ajana ver", "grupları başlat", "durum?", "oturumlara söyle", "merge et deploy et", "/solo-dispatch <görev|prompt dosyası>". İş Solo'daki remote (work container) veya yerel ajan oturumunda yürüyecekse.
argument-hint: <görev | orkestratör prompt dosyası>
disable-model-invocation: false
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion, Skill
---

# Solo Dispatch

Dağıtıcısın: görevi analiz etme, kod yazma; oturum aç, mesaj ilet, durumu raporla.

Script: `${CLAUDE_SKILL_DIR}/scripts/solo-agent.sh` (repo kökünde çalıştır; Solo projesi yoldan bulunur). Hedef: remote oturum `$N` (tmux id), yerel oturum `solo:<pid>`.

## 1. Başlatma

- Görevi analiz etmeden başlat. Varsayılan: tek remote oturum, prompt `/orchestrate <görev>`.
- Ayrı oturumlar yalnız kullanıcı söylerse veya prompt dosyası grup başına oturum diyorsa (`work-split` çıktısı).
- Oturum adı: `<Ana iş adı> - <harf> <kısa tanım>` (ör. `Vesentur faz 1 - A GA4 olayları`); tek işte `<Ana iş adı>`.
- Aynı anda en fazla 6 aktif grup; fazlası ve bağımlı gruplar (önkoşul PR merge) sırayla. Önkoşulu `gh pr view` ile doğrula.
- Prompt dosyasının sonuna ekle: karar kuralı (net karar → uygula, yalnız kesin onay gerekene tek blokta sor), tek PR, kanıt yalnız görsel işte, raporu `dw-share -d "<Ana iş adı>"` ile gönder, mesajları hafızaya yazma.
- `solo-agent.sh spawn remote "<ad>" <prompt-dosyası>`; Mac'te koşması gereken iş (iOS build, Mac'e özgü araç) → `spawn local`.
- Kapanan oturumu sürdür: transcript kimliğiyle `spawn remote "<ad>" --resume <uuid>` (kimlik: `~/.claude/projects/<proje>/*.jsonl` içinde görev metni).

## 2. İzleme

- Başlatınca arka planda `solo-agent.sh watch` izle; her olay satırında o oturumun ekranını oku.
- Kullanıcıya yalnız şunları ilet: açık soru (seçenekler + önerin), merge/deploy, rapor gönderimi, kota/limit, kural sapması. Ara durumu iletme.
- Rapor geldiğinde düz `~/Downloads/dw-share/` altına düştüyse `<Ana iş adı>/` klasörüne taşı; eski sürüm `eski/` altına.
- "durum?" → `solo-agent.sh status`; her oturum için ÇALIŞIYOR / BOŞTA / SORU ve son satırların özeti.
- Kullanıcının kendi oturumlarındaki sorulara cevap verme; özetle, kararı kullanıcıya bırak.

## 3. Mesaj iletme

- Toplu kural/karar mesajı: dosyaya yaz, `solo-agent.sh send <dosya> <hedef>...`. Script sona "hafızaya yazma" notunu ekler, soru penceresi açık oturumu atlar (`SKIP`) — o oturuma soru kapanınca gönder.
- "Tüm oturumlar" = remote oturumların hepsi + çalışan yerel Solo ajanları (`solo processes list --status running`).
- Oturumlar kural mesajını hafızaya yazmışsa ilgili memory dosyalarını sil; üzerine yazılan dosyayı transcript'teki önceki içeriğinden geri yükle.

## 4. Toplu merge ve deploy

- Merge durdurulduysa oturumlara "PR'ı hazır bırak, merge etme; deploy'a bağlı adımlar raporda" mesajını gönder.
- Toplu merge (Diji release-bot): scope'ta ilgili hedefleri `pinned` yap → PR'ları merge et (önce b2c-core, sonra b2b; registry değiştiyse b2b'de senkron PR'ı) → çakışan PR'ı sahibi oturuma rebase ettir → tüm PR'lar tag alınca hedefleri `auto` yap ve son sürümü bir kez deploy et → canlı sürümü doğrula. Deploy ayrıntıları: `work-diji-deploy`.
- Bitince PR sahibi oturumlara "merge edildi, canlı sürüm X; temizle ve merge sonrası işlerini yap" mesajını gönder.

## 5. Kapatma

- İşi biten oturumu kullanıcı isterse kapat: `solo-agent.sh close <hedef> [solo-pid]`.

## Ortam

- Remote bildirim: container `~/.claude/settings.json` `preferredNotifChannel: terminal_bell`; tmux `alert-bell` hook'u `~/.cache/tmux-bells.log`'a yazar (`~/.tmux.conf`). Eksikse `remote-workspace` ile kur.
- Solo bağlantısı koparsa tmux oturumları yaşar; yeniden bağlanmak için `dw -a <oturum adı>` komutlu ajanla aynı adla spawn et.
