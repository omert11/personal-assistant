---
name: commit
description: Commit oncesi kalite kontrol + teslimat secenekleri (commit, push, PR, branch).
when_to_use: Trigger — "commit", "commit at", "push et", "PR olustur", "branch ac", "degisiklikleri kaydet", "kodu gonder", "/commit". Her kod teslimat/kaydetme isteginde tetiklenir; manuel `git commit` yerine bu skill calisir.
disable-model-invocation: false
allowed-tools: Bash(git *), Bash(gh *), Read, Write, Edit, Grep, Glob, AskUserQuestion, Task, Skill
---

# Commit

Analizi sessizce yap, bulguları kendin düzelt, yalnız teslimatı sor (kullanıcı belirtmediyse), teslim et; ek sorular iş bitince.

## Akış

1. **Değişiklik** — `git status --porcelain`; boşsa "Commit edecek bir şey yok." de, çık.
1b. **Repo kuralları** — bkz. Repo kuralları.
2. **Branch**
   ```bash
   CURRENT_BRANCH=$(git branch --show-current)
   DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
   IS_MAIN=$([ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ] && echo true || echo false)
   IS_WORKTREE=$([ -f .git ] && echo true || echo false)
   ```
3. **Teslimat sorusu** — kullanıcı teslimatı söylemediyse şimdi sor (bkz. Sorular/Teslimat); cevap beklenirken analiz sürer. Söylediyse aynen uygula.
4. **Analiz** (paralel; review ve deslop arka planda, biri diğerini beklemez)
   - Diff: `git diff --stat`, `git diff --cached --stat` (staged varsa), `git diff`.
   - Deslop (bkz. Deslop).
   - Code review (bkz. Code review).
   - Test (bkz. Test).
   - Obsidian kayıt ihtiyacı (bkz. Obsidian).
5. **Düzelt** — tüm bulgular sormadan düzeltilir (bkz. Bulgu düzeltme). Sonra son analiz: atlanan bir şey var mı; yeni bulgu varsa düzelt.
6. **Commit** — onay beklemeden; `git add <ilgili-dosyalar>` + `git commit`.
   - Mesaj sorulmaz: diff özeti + branch adı + değişen dosyalardan İngilizce türet; conventional commit (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`) tercih, zorunlu değil. `dijii-tech` repolarında (origin URL'i) zorunlu; kırıcı değişiklikte `type!:`.
   - Her commit'te `Co-Authored-By: (MODEL)`.
7. **Pre-commit hook fail** — hatayı oku → otomatik düzelt (formatter, linter vb.) → yeniden stage + commit → hâlâ fail ise kullanıcıya göster: "Şu hata var, ne yapalım?"
8. **Teslimat** (seçime göre)
   - "PR + Merge + Clean" → branch aç (gerekirse), push, PR, merge, cleanup
   - "Branch + PR" / "PR oluştur" → branch aç (gerekirse), push, PR
   - "Push et" → `git push`
   - "Sadece commit" → hiçbir şey
9. **Branch adı** — sormadan: `feat/<kebab-case-konu>` (veya `fix/`, `chore/`, `docs/`), commit mesajının ana konusundan.
   ```bash
   BRANCH_NAME="feat/$(echo "$CONU" | tr '[:upper:]' '[:lower:]' | tr -s ' _' '-' | sed 's/[^a-z0-9-]//g')"
   git checkout -b "$BRANCH_NAME"
   ```
10. **PR** — `gh pr create`; başlık = commit subject. `dijii-tech` repolarında başlık conventional commit değilse conventional'a çevir (release-bot sürümü başlıktan üretir).
11. **Son sorular** — iş bitince (bkz. Sorular/Son).
12. **Sonuç özeti** — commit, teslimat, düzeltilen bulgular, deslop raporu, yazılmayan testler ve nedeni.

## Repo kuralları

- Dosya: `<repo kökü>/.agents/COMMIT_RULES.md`; varsa oku, skill varsayılanlarını ezer (Yasaklar hariç).
- `git check-ignore -q .agents/COMMIT_RULES.md` başarısız ve dosya tracked değilse: global ignore dosyasına (`git config --global core.excludesFile`, boşsa `~/.config/git/ignore`) `.agents/` satırını ekle.
- Kullanıcı kalıcı repo tercihi söylerse dosyaya madde olarak ekle.

## Deslop

- Tetik: diff'te son kullanıcının göreceği metin (doküman, template, çeviri, e-posta/store metni, kod içi UI string). Yalnız kod mantığı değiştiyse atla; kullanıcı "deslop atla" derse atla, özette belirt.
- `deslop` skill'ini çalıştır, hedef yalnız diff'teki bu dosyalar.

## Code review

- Kod değiştiyse zorunlu; yalnız kullanıcı açıkça isterse veya çağıran `orchestrate` akışı bu diff'i doğrulamada incelediyse atla.
- Komut (arka planda, repo/worktree kökünde): `cd <root> && claude -p '/code-review low'`
- Bekleme: her arka plan oturumunun PID'ini (`$!`) sakla, bitişi `ps -p <PID>` ile bekle; `pgrep -f` ile bekleme.
- `/code-review` ile başlayan oturumdaysan delegasyon yapma, doğrudan koş.
- Hata/timeout → tekrar dene.
- Büyük diff → modül bazlı 3-4 paralel oturum (`… -p '/code-review low — sadece <küme>'`), sonuçları birleştir.
- Review tek tur; tüm bulgular (uncertain dahil) düzeltilir, düzeltme sonrası tekrar review yok.

## Bulgu düzeltme

- >5 bulgu veya 3+ dosya → dosya bazında paralel sub-agent'lar; aksi hâlde kendin düzelt.

## Test

- Değişen kodun testi yoksa gerekip gerekmediğine karar ver: davranış/mantık değişikliği ve projede test altyapısı varsa yaz; config, metin, trivial değişiklik veya test altyapısı yoksa yazma.
- Yazılan testler commit'e girer; yazılmayanlar nedeniyle özette.

## Obsidian

- Vault'a yazılacak kalıcı bilgi (sistem/araç/servis gerçekte nasıl çalışıyor; credential/sunucu/endpoint dahil) veya karar (kalıcı hüküm) var mı (`obsidian-write` skill).
- Bug'ın kendisi değil nihai öğretisi sayılır. Repo/AGENTS.md/vault'ta yazılı bilgi, oturum özeti, geçici durum sayılmaz; şüphedeysen önerme.

## Sorular

Tümü soru aracıyla sorulur; blok başına max 4 soru; önerilen seçenek ilk sırada, `(Recommended)` etiketli.

### Teslimat (başta, kullanıcı belirtmediyse)

header `Teslimat`, question `Commit sonrası ne yapayım?`

- Ana branch'te: "PR + Merge + Clean" — branch aç, push, PR, merge, cleanup · "Branch + PR" — branch aç, push, PR (merge etme) · "Push et" — direkt `git push` (risky) · "Sadece commit" — local bırak
- Feature branch'te: "PR + Merge + Clean" — push, PR, merge, cleanup · "PR oluştur" — push, PR (merge etme) · "Push et" — sadece `git push` · "Sadece commit" — local bırak
- Recommended: `COMMIT_RULES.md`'deki teslimat tercihi; yoksa "PR + Merge + Clean".

### Son (iş bitince, yalnız koşulu sağlananlar, tek blok)

- **Obsidian** (bulgu varsa) — header `Obsidian`, question `Bu commit'te kayda değer bilgi var. Obsidian vault'a yazayım mı?`, options `["Evet, obsidian-write ile yaz", "Hayır, geç"]`. Evet → ana agent `obsidian-write` skill'ini çağırır (subagent yok).

## Yasaklar

- Düz metin soru; kesik kesik soru (her bulgu için ayrı soru).
- `git add -A` / `git add .` (hassas dosya riski).
- `--no-verify`; `--amend` (her zaman yeni commit).
- Ana branch'e `git push --force` (uyar).
- Code review'u atlamak/ertelemek/koşula bağlamak (Code review bölümündeki iki istisna hariç); "hızlıca commit", "direkt commit", "test geçiyor", "trivial" gerekçe değildir.
- `/code-review`'u doğrudan çağırmak, code-review'u sub-agent'a ya da başka bir araçla koşturmak; path'i `cd` yerine yalnız prompt'a yazmak.
- Review bulgularını "küçük/önemsiz/stil" diye filtrelemek, false positive sandığını elemek, şiddeti yumuşatmak, review'i kısa kesmek, kullanıcı baskısıyla bulgu gizlemek.
- Hata/boş/timeout veren review'u sessizce geçmek.
