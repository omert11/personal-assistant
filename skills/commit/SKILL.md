---
name: commit
description: Kod degisikliklerini commit etmeden once kalite kontrol akisi uygular ve sonunda kullaniciya teslimat secenekleri sunar. Bu skill'i su durumlarda kullan kullanici "commit", "commit at", "push et", "PR olustur", "branch ac", "degisiklikleri kaydet", "kodu gonder", "/commit" dediginde. Kodla ilgili herhangi bir teslimat/kaydetme isteginde bu skill tetiklenmeli.
disable-model-invocation: false
allowed-tools: Bash(git *), Bash(gh *), Read, Grep, Glob, AskUserQuestion, Task
---

# Commit Skill

Kod değişikliklerini commit etmeden önce **toplu analiz** yapar, soruları biriktirir, tek seferde kullanıcıya sunar, onay sonrası teslim eder.

## Temel İlke

**Kullanıcıyı az kes.** Her hata için ayrı soru sorma. Önce tüm analizi yap, bulguları biriktir, sonunda **tek bir AskUserQuestion bloğunda** topla.

## İş Akışı

### 1. Ön Kontrol — Değişiklik Var mı?

```bash
git status --porcelain
```

Boşsa: **"Commit edecek bir şey yok."** deyip çık. Skill sonlanır.

### 2. Branch Tespit

```bash
CURRENT_BRANCH=$(git branch --show-current)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
IS_MAIN=$([ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ] && echo true || echo false)
IS_WORKTREE=$([ -f .git ] && echo true || echo false)
```

Bu bilgiyi son adımdaki teslimat seçenekleri için kullan.

### 3. Toplu Analiz (sıralı, sessiz)

Her adımda bulguları **belleğe topla**, bitince hepsini birden sun.

#### 3a. Değişiklikleri Çıkar
```bash
git diff --stat
git diff --cached --stat  # staged varsa
git diff
```

#### 3b. /simplify Çalıştır — ZORUNLU (kod değişikliği varsa)

**Kural kesin**: `git diff --stat` çıktısında herhangi bir **kod dosyası** (`.py`, `.js`, `.ts`, `.tsx`, `.jsx`, `.go`, `.rs`, `.java`, `.kt`, `.swift`, `.dart`, `.rb`, `.php`, `.c`, `.cpp`, `.cs`, `.sh`, `.vue`, `.svelte`) değişmişse `/simplify` skill'i **mutlaka** çalıştırılır.

- **Atlanamaz**, **ertelenemez**, **koşula bağlanamaz**.
- Kullanıcı "commit at hadi", "hızlıca commit", "direkt commit" dese bile önce `/simplify` çalışır.
- Sadece **non-kod dosyaları** (`.md`, `.json`, `.yml`, `.txt`, asset'ler) değişmişse atlanabilir.
- Skip sadece kullanıcı **açıkça** "simplify atla" / "skip simplify" / "simplify çalıştırma" derse mümkün — bu durumda bulgu olarak "kullanıcı explicit skip istedi" diye işaretle.

Çıktıyı bulgu olarak topla. Simplify değişiklik önerdiyse Soru 1'e dahil et.

#### 3c. Test Kontrolü
- Değişen dosyaların test'i var mı? (`*.test.*`, `*_test.*`, `tests/`, `__tests__/`)
- Yoksa **bulgu olarak işaretle** (sormak için bekle)

#### 3d. Rules Uyum Kontrolü
`~/.claude/rules/` altındaki kuralları gözden geçir:
- `coding.md` — TODO yorumları, error wrapping, dil ayrımı (Türkçe iletişim, İngilizce kod)
- `python.md` — uv kullanımı (pip değil)
- `django.md` — F7 çeviri, uv kurulum
- `before-commit.md` — bu skill'in ana referansı

İhlal varsa bulgu olarak topla.

#### 3e. Vikunja Görev Bağlantısı
`CLAUDE.local.md`'de Vikunja proje ID varsa:
```
vikunja-cli task list --filter "done = false" --json ile aktif görevleri getir
```
Yapılan değişikliklerle uyuşan bir görev var mı tespit et:
- **Var**: ID'sini sakla (sonra kapat)
- **Yok**: bulgu olarak işaretle (yeni görev önerisi için)

#### 3f. Obsidian Kayıt İhtiyacı
`CLAUDE.local.md`'de `Obsidian Folder` varsa bu commit'te kaydedilmesi kayda değer bir şey var mı tespit et:
- Yeni API key, sunucu bilgisi, teknik karar, kalıcı komut, tekrar eden pattern
- Büyük mimari değişiklik (commit mesajı `feat:` veya `refactor:` başlıklı + >100 satır diff)

Varsa bulgu olarak işaretle. Yoksa sessiz geç.

### 4. Toplu Soru Bloğu — Olabildiğince Tek Seferde

**Temel Kural**: Tüm bulgular + teslimat seçimi **önceden toplu sorulur**. Kesik kesik soru yasak. Max 4 soru/blok; 4'ten fazla soru varsa art arda (2. faz) blok.

**Commit mesajı otomatik türetilir — SORULMAZ.** Conventional commit format (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`) tercih edilir. Diff özeti + branch ismi + değişen dosyalardan türet.

#### Faz 1 — Ana Blok (≤4 soru)

Aktif olanları (koşul sağlanan) sıraya koy, ilk 4'ünü tek blokta sor:

**S1 — Tespit Edilen Sorunlar** (varsa)
- header: "Sorunlar"
- question: "Şu bulgular var: [/simplify: X, rules ihlal: Z]. Düzelteyim mi?"
- options: ["Evet, düzelt" (Recommended), "Sadece kritikleri düzelt", "Geçiştir, commit et"]

**S2 — Test Eksikse** (3c bulgusu varsa)
- header: "Test"
- question: "Test yazılmamış: [dosyalar]. Ne yapalım?"
- options: ["Test yaz", "Testsiz devam et"]

**S3 — Vikunja** (proje ID varsa)
- Görev varsa: header "Vikunja", question "Görev #X'i kapatayım mı?", options ["Evet kapat (DONE)", "Açık bırak"]
- Görev yoksa: question "Bu değişiklik için Vikunja'da görev oluşturayım mı (DONE olarak)?", options ["Evet", "Hayır"]

**S4 — Teslimat** (branch'e göre değişir)

Ana branch'te (main/master):
- header: "Teslimat"
- question: "Commit sonrası ne yapayım?"
- options:
  - "PR + Merge + Clean" (Recommended) — branch aç, push, PR, merge, cleanup
  - "Branch + PR" — branch aç, push, PR (merge etme)
  - "Push et" — direkt `git push` (risky)
  - "Sadece commit" — local bırak

Feature branch'te:
- header: "Teslimat"
- question: "Commit sonrası ne yapayım?"
- options:
  - "PR + Merge + Clean" (Recommended) — push, PR, merge, cleanup
  - "PR oluştur" — push, PR (merge etme)
  - "Push et" — sadece `git push`
  - "Sadece commit" — local bırak

#### Faz 2 — Ek Blok (koşullu, ≤4 soru)

Faz 1'de yer kalmayan veya koşullu sorular:

**S5 — Obsidian** (3f bulgusu varsa)
- header: "Obsidian"
- question: "Bu commit'te kayda değer bilgi var. Obsidian klasörüne not ekleyeyim mi?"
- options: ["Evet, obsidian-writer ile ekle", "Hayır, geç"]
- Evet seçilirse commit sonrası `Task` ile `obsidian-writer MODE: append` çağır.

**S6 — Worktree** (worktree'deyse)
- header: "Worktree"
- question: "Worktree'desin. `worktree` skill'i çalıştırayım mı (PR + merge + cleanup)?"
- options: ["Evet, worktree skill çalıştır", "Hayır, sadece commit"]

**Kural**: Faz 2 sadece gerçekten ek soru varsa tetiklenir. Yoksa Faz 1 sonrası direkt commit + teslimat.

Sorunlar düzeltildikten sonra **son bir analiz** yap: "Atladığım bir şey var mı?" Yeni bulgu varsa tek ek blok ile sor.

### 5. Commit

```bash
git add <ilgili-dosyalar>  # asla `git add -A` veya `git add .` kullanma (sensitive dosya riski)
```

```bash
git commit -m "$(cat <<'EOF'
<commit mesajı>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Co-Authored-By her zaman eklenir.**

### 6. Pre-commit Hook Fail Olursa

1. Hata mesajını oku
2. Otomatik düzelt (formatter, linter, vb.)
3. Yeniden stage + commit dene
4. Hâlâ fail ise kullanıcıya göster: "Şu hata var, ne yapalım?"

**Asla `--no-verify` kullanma.**

### 7. Teslimat Uygulama

Teslimat seçimi **Faz 1 S4**'te alındı. Commit sonrası seçime göre uygula:
- "PR + Merge + Clean" → branch aç (gerekirse), push, PR, merge, cleanup
- "Branch + PR" / "PR oluştur" → branch aç (gerekirse), push, PR
- "Push et" → `git push`
- "Sadece commit" → hiçbir şey yapma

### 8. Branch İsmi

Yeni branch açma seçildiğinde:
- Format: `feat/<kebab-case-konu>` veya `fix/`, `chore/`, `docs/` prefix'leriyle
- Commit mesajının ana konusundan otomatik türet
- **Kullanıcıya sorma**, direkt aç

```bash
BRANCH_NAME="feat/$(echo "$CONU" | tr '[:upper:]' '[:lower:]' | tr -s ' _' '-' | sed 's/[^a-z0-9-]//g')"
git checkout -b "$BRANCH_NAME"
```

### 9. PR Oluşturma

```bash
gh pr create --title "<commit subject>" --body "$(cat <<'EOF'
## Summary
<1-3 madde>

## Test plan
- [ ] <test maddeleri>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 10. Vikunja Kapatma

Soru 3'te "Evet kapat" seçildiyse:
```
vikunja-cli task update <id> --done ile status: done yap
```

Görev yoksa ve "Evet" seçildiyse:
```
vikunja-cli task create --project-id <pid> --title "<özet>" --done ile yeni görev oluştur
```

## Kritik Kurallar

- **Asla onay almadan commit atma**
- **Asla `git add -A` veya `git add .`** — dosyaları tek tek seç
- **Asla `--no-verify`** — hook fail ise düzelt
- **Asla `--amend`** — yeni commit oluştur (önceki yanlış olabilir)
- **Asla `git push --force` ana branch'e** (uyar)
- **Co-Authored-By her commit'te**
- Conventional commit **tercih edilir** ama zorlama
- Türkçe iletişim, İngilizce commit mesajı

## İlişkili Dosyalar

- `~/.claude/rules/before-commit.md` — bu skill'in temel kuralları
- `~/.claude/rules/coding.md` — kod kalite kuralları
- `~/.claude/rules/ask-first.md` — AskUserQuestion kullanım kuralları
- `worktree` skill (varsa) — worktree teslim akışı
