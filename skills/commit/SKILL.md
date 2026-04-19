---
name: commit
description: Kod degisikliklerini commit etmeden once kalite kontrol akisi uygular ve sonunda kullaniciya teslimat secenekleri sunar. Bu skill'i su durumlarda kullan kullanici "commit", "commit at", "push et", "PR olustur", "branch ac", "degisiklikleri kaydet", "kodu gonder", "/commit" dediginde. Kodla ilgili herhangi bir teslimat/kaydetme isteginde bu skill tetiklenmeli.
disable-model-invocation: false
allowed-tools: Bash(git *), Bash(gh *), Bash(wt *), Read, Grep, Glob, AskUserQuestion
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

#### 3b. /simplify Çalıştır
Değişen kod üzerinde `/simplify` skill'ini çalıştır. Çıktıyı bulgu olarak topla.

#### 3c. /review Çalıştır
Aynı kod üzerinde `/review` skill'ini çalıştır. Çıktıyı topla.

#### 3d. Test Kontrolü
- Değişen dosyaların test'i var mı? (`*.test.*`, `*_test.*`, `tests/`, `__tests__/`)
- Yoksa **bulgu olarak işaretle** (sormak için bekle)

#### 3e. Rules Uyum Kontrolü
`~/.claude/rules/` altındaki kuralları gözden geçir:
- `coding.md` — TODO yorumları, error wrapping, dil ayrımı (Türkçe iletişim, İngilizce kod)
- `python.md` — uv kullanımı (pip değil)
- `django.md` — F7 çeviri, uv kurulum
- `before-commit.md` — bu skill'in ana referansı

İhlal varsa bulgu olarak topla.

#### 3f. Vikunja Görev Bağlantısı
`CLAUDE.local.md`'de Vikunja proje ID varsa:
```
mcp__vikunja__vikunja_list_tasks ile aktif görevleri getir
```
Yapılan değişikliklerle uyuşan bir görev var mı tespit et:
- **Var**: ID'sini sakla (sonra kapat)
- **Yok**: bulgu olarak işaretle (yeni görev önerisi için)

### 4. Toplu Soru Bloğu

Bütün bulguları **tek `AskUserQuestion` çağrısında** sun (max 4 soru, gerekirse art arda blok). Sıra:

**Soru 1 — Tespit Edilen Sorunlar (varsa)**
- header: "Sorunlar"
- question: "Şu bulgular var: [/simplify: X, /review: Y, rules ihlal: Z]. Düzelteyim mi?"
- options:
  - "Evet, düzelt" (Recommended)
  - "Sadece kritikleri düzelt"
  - "Geçiştir, commit et"

**Soru 2 — Test Eksikse**
- header: "Test"
- question: "Test yazılmamış: [dosyalar]. Ne yapalım?"
- options: ["Test yaz", "Testsiz devam et"]

**Soru 3 — Vikunja**
- Görev varsa: header "Vikunja", question "Görev #X'i kapatayım mı?", options ["Evet kapat (DONE)", "Açık bırak"]
- Görev yoksa: question "Bu değişiklik için Vikunja'da görev oluşturayım mı (DONE olarak)?", options ["Evet", "Hayır"]

**Soru 4 — Commit Mesajı**
- header: "Commit"
- question: "Commit mesajı: '<önerilen mesaj>'. Onaylıyor musun?"
- options: ["Evet", "Düzenle", "İptal"]
- Format: Conventional commit (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`) **tercih edilir** ama zorunlu değil. Otomatik öner ama kullanıcı düzenleyebilsin.

Sorunlar düzeltildikten sonra **son bir analiz** yap: "Atladığım bir şey var mı?" diye kendi kendine kontrol et. Yeni bulgu varsa kullanıcıya bildir.

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

### 7. Teslimat Seçenekleri

Branch'a göre `AskUserQuestion`:

#### Ana Branch'te (main/master)
- header: "Teslimat"
- question: "Commit atıldı. Sonra ne yapayım?"
- options:
  - "Push et" — `git push`
  - "Branch + PR" — feat/<konu> branch oluştur, push, `gh pr create`
  - "PR + Merge + Clean" — PR aç, merge et, branch temizle (Recommended)

#### Feature Branch'te
- header: "Teslimat"
- question: "Commit atıldı. Sonra ne yapayım?"
- options:
  - "Push et" — `git push`
  - "PR oluştur" — `gh pr create`
  - "PR + Merge + Clean" — PR aç, merge et, branch temizle (Recommended)

#### Worktree'deyse
Yukarıdaki seçimden bağımsız olarak en sonda ek soru:
- header: "Worktree"
- question: "Worktree'desin. `worktree` skill'i çalıştırayım mı (PR + merge + cleanup)?"
- options: ["Evet, worktree skill çalıştır", "Hayır, sadece commit"]

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
mcp__vikunja__vikunja_update_task ile status: done yap
```

Görev yoksa ve "Evet" seçildiyse:
```
mcp__vikunja__vikunja_create_task ile yeni görev oluştur, status: done
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
