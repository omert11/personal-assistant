---
name: worktree
description: Git worktree yönetimi (Claude Code native --worktree/EnterWorktree wrapper).
when_to_use: Trigger — "worktree aç", "worktree oluştur", "yeni worktree", "worktree'ye gir/çık", "paralel çalışalım", "izole branch'te çalış", "worktree'leri listele/sil/temizle", "subagent'ları paralel worktree'de", "worktree'den PR aç", "/worktree". Feature/bugfix izolasyon, paralel subagent, .worktreeinclude kurulum, merged temizlik, durum raporu.
disable-model-invocation: false
allowed-tools: Bash(git *), Bash(gh *), Bash(claude *), Read, Write, Edit, Grep, Glob, AskUserQuestion, Task, EnterWorktree, ExitWorktree
---

# Worktree Skill

Claude Code native `--worktree` mekanizmasına **delege eden** wrapper. Session içi izolasyon `EnterWorktree`/`ExitWorktree` tool'larıyla yapılır. Toplu yönetim, paralel subagent koordinasyonu, PR akışı için.

- Dizin: `<repo>/.claude/worktrees/<isim>/`
- Branch: `worktree-<isim>`
- Base: `HEAD` (EnterWorktree default) veya `origin/HEAD` (`claude -w` CLI flag default)
- Native uyum: `claude --worktree`, `EnterWorktree`, `ExitWorktree`, `isolation: worktree` (subagent), `.worktreeinclude`, `cleanupPeriodDays`

## Komut Seti

Argüman yoksa `AskUserQuestion` ile alt komut sor.

### `new <isim>` — Session içinde worktree'ye gir

**Native tool delege** — `EnterWorktree` çağır:

```
EnterWorktree({ name: "<isim>" })
```

- İsim verilmezse random
- Mevcut worktree'ye girmek için: `EnterWorktree({ path: "<mevcut-path>" })` (path `git worktree list`'de olmalı)
- Session cwd otomatik worktree'ye geçer
- Çıkış: `ExitWorktree({ action: "keep" | "remove" })`

Yeni bir session'da worktree açmak için (bu session'ı kilitlemeden):

```
claude --worktree <isim>           # yeni session, izole worktree
claude --worktree <isim> --tmux    # tmux session (iTerm2 native panes veya --tmux=classic)
```

### `enter <isim-veya-path>` — Mevcut worktree'ye gir

```
EnterWorktree({ path: "<repo>/.claude/worktrees/<isim>" })
```

Manuel `git worktree add` ile oluşturulmuş worktree'ler için `path` kullan.

### `exit [keep|remove]`

```
ExitWorktree({ action: "keep" })
# veya temiz ise:
ExitWorktree({ action: "remove" })
# dirty/commits varsa remove için:
ExitWorktree({ action: "remove", discard_changes: true })
```

Sadece `EnterWorktree` ile girilmiş worktree'yi etkiler. Manuel `git worktree add` ile oluşturulanlara dokunmaz.

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
3. Commit akışı için `commit` skill'ine delege et
4. `gh pr create --base <base> --head worktree-<isim>`

PR açıldıktan sonra kullanıcıya sor: merge sonrası worktree otomatik silinsin mi → evet ise `clean --merged` öner.

### `clean [--merged|--all|<isim>]`

- `--merged`: PR'ı merge olmuş worktree'leri bul (`gh pr list --state merged`), tek tek `AskUserQuestion` ile onay
- `<isim>`: Spesifik worktree sil (dirty ise uyar)
- `--all`: Tüm safe-to-remove worktree'leri sil

```bash
git worktree remove <path>
git branch -D worktree-<isim>
```

Dirty worktree için ASLA otomatik silme.

**Native auto-sweep:** Claude Code `cleanupPeriodDays` setting ile orphan **subagent** worktree'lerini otomatik temizler (uncommitted yok + untracked yok + unpushed yok koşuluyla). `--worktree` veya `EnterWorktree` ile açılanları silmez. Manuel cleanup bunun yanında çalışır.

### `setup`

Proje ilk kurulum (idempotent):

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)

# .worktreeinclude (gitignore syntax — NATIVE)
# Sadece gitignore'da olan + pattern match dosyalar kopyalanır
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

#### Büyük gitignore'lu asset dizinleri → SYMLINK (kopyalama değil)

`.worktreeinclude` dosyaları **kopyalar**. Yüzlerce/binlerce dosyalı, sık güncellenen
asset dizinleri (örn. yüklenen logolar, medya, generated cache) için kopyalama hem
disk israfı (her worktree × N MB) hem de bayatlama (kopya anındaki halde kalır) demek.
Bu tür dizinleri `.worktreeinclude`'a EKLEME — bunun yerine worktree oluşturulduktan
sonra ana repo'daki dizine **symlink** kur (tek kaynak, anında güncel, disk israfı yok):

```bash
# Worktree oluştuktan sonra (new akışı sonrası), her büyük asset dizini için:
# WT_PATH = yeni worktree kök dizini, REPO_ROOT = ana repo kökü
link_asset_dir() {  # $1 = repo-relative asset dir (örn. backend/cmd/api/uploads)
  local rel="$1" src="$REPO_ROOT/$1" dst="$WT_PATH/$1"
  [ -e "$src" ] || return 0                 # ana repo'da yoksa atla
  [ -e "$dst" ] && return 0                  # zaten varsa (symlink/kopya) dokunma
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "→ symlink: $rel"
}
# Proje-spesifik asset dizinleri (CLAUDE.local.md/CLAUDE.md'den veya bilinen yoldan):
#   b2b-dmc: backend/cmd/api/uploads (airline-logos vb. ~1132 dosya)
link_asset_dir "backend/cmd/api/uploads"
```

> Symlink gitignore'lu hedefi gösterdiğinden commit'e girmez; ana repo asset'i
> güncellenince tüm worktree'ler anında güncel görür. `new` akışında worktree
> oluştuktan sonra bu adımı çalıştır (idempotent — zaten varsa atlar).

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

## Native Tool & Flag Referansı

### Session içi tools

| Tool | İş |
|---|---|
| `EnterWorktree({ name })` | Yeni worktree oluştur + session cwd'yi içine al. Base = `HEAD`. İsim verilmezse random |
| `EnterWorktree({ path })` | Mevcut worktree'ye gir (path `git worktree list`'de olmalı) |
| `ExitWorktree({ action: "keep" })` | Worktree'den çık, directory+branch korunur |
| `ExitWorktree({ action: "remove" })` | Worktree'den çık, directory+branch silinir. Dirty ise `discard_changes: true` gerekir |

Kısıt: `EnterWorktree` sadece **git repo içinde** VEYA `WorktreeCreate/WorktreeRemove` hook yapılandırıldığında çalışır. Zaten worktree'deyken çağrılamaz. `ExitWorktree` sadece aynı session'daki `EnterWorktree`'yi geri alır — dışarıdan oluşturulan worktree'lere dokunmaz.

### CLI flags (yeni session açarken)

| Flag | İş |
|---|---|
| `claude --worktree <isim>` / `-w <isim>` | Izole worktree + session başlat. Base = `origin/HEAD`. İsim verilmezse random |
| `claude --worktree --tmux` | Tmux session. `--tmux=classic` traditional tmux, default iTerm2 native panes |

### Subagent frontmatter

```yaml
---
isolation: worktree
---
```

Agent kendi worktree'sinde çalışır, değişiklik yoksa auto-remove.

## `.worktreeinclude` (NATIVE SYNTAX)

`.gitignore` syntax — glob/pattern eşleşir. Sadece **gitignore'da olan + pattern match** dosyalar kopyalanır. Tracked dosyalar asla duplike olmaz.

```
.env
.env.local
config/secrets.json
**/*.key
```

`--worktree`, `EnterWorktree`, subagent worktree, desktop app parallel sessions hepsine uygulanır.

## Base Branch Tespit

Hangi tool kullanıldığına göre farklı:

- **`EnterWorktree`** → `HEAD` (mevcut branch tip'i)
- **`claude --worktree` / `-w`** → `origin/HEAD` (remote default branch)

`origin/HEAD` yanlışsa remote default'u local'e senkronla (idempotent):

```bash
git remote set-head origin -a
```

Farklı branch sabit base olsun istiyorsan:

```bash
git remote set-head origin your-branch-name
```

## Cleanup Semantic

Native davranış:
- **No changes** (uncommitted yok + untracked yok + commit yok) → auto-remove
- **Changes/commits var** → kullanıcıya sor (keep/remove)
- **Subagent worktree orphan** → `cleanupPeriodDays` eşiğinden eski + temiz ise auto-sweep
- **`--worktree` / `EnterWorktree` ile açılanlar** → sweep'e dahil değil

Skill tarafı safe-to-remove check:

```bash
UNPUSHED=$(git -C <path> rev-list --count @{u}..HEAD 2>/dev/null || echo -1)
DIRTY=$(git -C <path> status --porcelain)

[ -z "$DIRTY" ] && [ "$UNPUSHED" = "0" ] && echo "safe-to-remove"
```

Upstream yoksa unsafe say, kullanıcıya sor.

## Session Picker Worktree Entegrasyonu

Native `/resume` davranışı:
- Default: mevcut worktree session'larını gösterir
- `Ctrl+W`: repo'nun tüm worktree'leri
- `Ctrl+A`: tüm projeler
- `claude --resume <name>`: worktree'ler arası isim çözümlemesi

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
3. Alt komut adımlarını uygula (session içi işler için `EnterWorktree`/`ExitWorktree` kullan)
4. Özet göster
5. Takip komutu öner

## Entegrasyon Notları

- **Session içi izolasyon**: `EnterWorktree` bu session'ı worktree'ye taşır (cwd değişir). `ExitWorktree` geri döndürür. Yeni session için `claude -w <isim>` öner
- **Dışarıdan oluşturulmuş worktree'ye girmek için**: `EnterWorktree({ path: "..." })` — path `git worktree list`'te olmalı
- **Base branch farkı**: `EnterWorktree` = `HEAD`, `claude -w` = `origin/HEAD`. Kullanıcı ne istediğini netleştir
- **.worktreeinclude syntax**: gitignore glob (regex değil)
- **Commit delege**: `pr` akışı commit mantığını `commit` skill'ine bırakır (DRY)
- **Auto-cleanup**: Native Claude sweep `cleanupPeriodDays` ile orphan subagent worktree'leri temizler — skill bunu tamamlar
