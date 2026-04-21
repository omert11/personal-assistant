---
name: worktree
description: Git worktree yönetimi. Claude Code'un native --worktree/-w flag'i ve subagent isolation: worktree desteği ile uyumlu. Bu skill'i şu durumlarda kullan — kullanıcı "worktree aç", "worktree oluştur", "yeni worktree", "paralel çalışalım", "izole branch'te çalış", "worktree'leri listele", "worktree sil", "worktree temizle", "bu feature için ayrı worktree", "subagent'ları paralel worktree'de çalıştır", "worktree'den PR aç", "/worktree" dediğinde. Yeni feature/bugfix/experiment izolasyonu, paralel subagent koordinasyonu, .worktreeinclude + .gitignore kurulumu, merged worktree temizliği, worktree durumu raporlama için.
disable-model-invocation: false
allowed-tools: Bash(git *), Bash(gh *), Read, Write, Edit, Grep, Glob, AskUserQuestion, Task
---

# Worktree Skill

Git worktree'ler ile paralel/izole çalışma. Claude Code'un native mekanizmasına uyumlu:

- Dizin: `<repo>/.claude/worktrees/<isim>/`
- Branch: `worktree-<isim>`
- Base: `origin/HEAD` (default remote branch)
- `.worktreeinclude` destekli
- Subagent `isolation: worktree` frontmatter uyumlu

## Komut Seti

Argüman yoksa `AskUserQuestion` ile alt komut sor.

### `new <isim> [base]`

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
BASE=${BASE:-$(git symbolic-ref refs/remotes/origin/HEAD --short | sed 's|origin/||')}
WT_PATH="$REPO_ROOT/.claude/worktrees/<isim>"
git worktree add "$WT_PATH" -b "worktree-<isim>" "origin/$BASE"
```

Sonra `.worktreeinclude` pattern'lerini kopyala (aşağı bak).

### `list` / `status`

```bash
git worktree list --porcelain
# Her worktree için (cd yerine -C kullan):
git -C <path> status --porcelain
git -C <path> log -1 --oneline
git -C <path> rev-list --left-right --count worktree-<isim>...origin/<base>
```

Sonucu tablo halinde sun.

### `pr <isim>`

Worktree'den PR aç:

1. `git -C <worktree-path> push -u origin worktree-<isim>`
2. Base branch'i `git -C <path> config --get branch.worktree-<isim>.merge` ile veya `origin/HEAD`'den al
3. Commit akışı için `commit` skill'ine delege et (pre-commit hook, commit message formatı orada)
4. `gh pr create --base <base> --head worktree-<isim>`

PR açıldıktan sonra kullanıcıya sor: merge sonrası worktree otomatik silinsin mi → evet ise `clean --merged` öner.

### `clean [--merged|--all|<isim>]`

- `--merged`: PR'ı merge olmuş worktree'leri bul (`gh pr list --state merged`), tek tek `AskUserQuestion` ile onay
- `<isim>`: Spesifik worktree sil (dirty ise uyar)
- `--all`: Tüm safe-to-remove worktree'leri sil (aşağı bak)

```bash
git worktree remove <path>
git branch -D worktree-<isim>
```

Dirty worktree için ASLA otomatik silme.

### `setup`

Proje ilk kurulum (idempotent):

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)

# .worktreeinclude (append-if-missing)
cat > "$REPO_ROOT/.worktreeinclude" <<'EOF'
.env
.env.local
.env.*.local
config/secrets.json
EOF

# .gitignore'a ekle (append-if-missing)
grep -qxF '.claude/worktrees/' "$REPO_ROOT/.gitignore" 2>/dev/null \
  || echo '.claude/worktrees/' >> "$REPO_ROOT/.gitignore"

# origin/HEAD senkronla (idempotent)
git -C "$REPO_ROOT" remote set-head origin -a
```

### `parallel <sayı> <görev-açıklaması>`

N subagent'ı ayrı worktree'lerde paralel başlat. **Task** tool'unu `isolation: "worktree"` ile tek mesajda N kez çağır:

```
Task({
  description: "parallel task 1/N",
  subagent_type: "general-purpose",
  isolation: "worktree",
  prompt: "<görev-açıklaması> — iteration 1/N. ..."
})
```

Her agent izole kopyada çalışır. Değişiklik yoksa Claude otomatik temizler.

## `.worktreeinclude` Kopyalama

Single-pass, null-safe:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
INCLUDE="$REPO_ROOT/.worktreeinclude"
[ -f "$INCLUDE" ] || exit 0

# Yorum ve boş satırları çıkar, pattern listesi üret
PATTERNS=$(grep -Ev '^\s*(#|$)' "$INCLUDE")
[ -z "$PATTERNS" ] && exit 0

# Tek git ls-files çağrısı, null-delimited stream
git -C "$REPO_ROOT" ls-files -z --others --ignored --exclude-standard \
  | while IFS= read -r -d '' file; do
      if echo "$PATTERNS" | grep -qE -- "$(echo "$file" | sed 's/[.[\*^$]/\\&/g')"; then
        mkdir -p "$WT_PATH/$(dirname "$file")"
        cp "$REPO_ROOT/$file" "$WT_PATH/$file"
      fi
    done
```

NOT: Pattern gitignore-glob değil regex olarak eşleşir (basit isimler için yeterli; kompleks glob'lar için `fnmatch` gerekir).

## Base Branch Tespit

Öncelik:
1. Kullanıcı açıkça verdi → onu kullan
2. `git symbolic-ref refs/remotes/origin/HEAD --short` → `origin/main` / `origin/master`
3. Çıkmazsa: `git -C "$REPO_ROOT" remote set-head origin -a` (idempotent), tekrar dene
4. Hâlâ çıkmazsa: `AskUserQuestion` ile branch listesi sun

## Cleanup Semantic (Claude native ile tutarlı)

Safe-to-remove tek komutla:

```bash
# Upstream varsa unpushed commit sayısı, yoksa -1 (unsafe say)
UNPUSHED=$(git -C <path> rev-list --count @{u}..HEAD 2>/dev/null || echo -1)
DIRTY=$(git -C <path> status --porcelain)

[ -z "$DIRTY" ] && [ "$UNPUSHED" = "0" ] && echo "safe-to-remove"
```

Herhangi biri fail → kullanıcıya sor, asla zorlama.

Upstream tanımlı değilse → unsafe say, kullanıcıya sor.

## Çıktı Formatı

Tablo. Emoji yok (global kural).

```
BRANCH                    PATH                                    STATE    AHEAD/BEHIND   LAST COMMIT
worktree-auth-refactor    .claude/worktrees/auth-refactor          dirty    +3/-0          Add OAuth2 flow
worktree-bugfix-123       .claude/worktrees/bugfix-123             clean    +0/-0          Fix null pointer
```

## Session Akışı

1. Argüman parse et, yoksa `AskUserQuestion` ile alt komut sor
2. Git repo kontrol → değilse hata ver
3. Alt komut adımlarını uygula
4. Özet göster
5. Takip komutu öner (örn. `new` sonrası: `claude --worktree <isim>` veya `cd <path> && claude`)

## Entegrasyon Notları

- **Native Claude uyum**: Dizin + branch konvansiyonu, `.worktreeinclude` davranışı, cleanup semantic Claude'un `--worktree` flag'i ile birebir aynı
- **Session geçişi**: Bu session worktree'ye cd yapmaz (tool call'lar arası persist etmez). Kullanıcıya `claude --worktree <isim>` öner
- **Commit delege**: `pr` akışı commit mantığını `commit` skill'ine bırakır (DRY)
- **Auto-cleanup**: Native Claude sweep `cleanupPeriodDays` ile orphan subagent worktree'leri temizler — bu skill onu bozmaz
