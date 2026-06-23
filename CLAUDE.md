# personal-assistant

Claude Code için kişisel asistan plugin'i. Oturum başında kuralları yükler, proje yapılandırmasını denetler, tekrarlayan işler için özel skill'ler sağlar.

## Stack

- Claude Code plugin (marketplace uyumlu)
- Shell (bash, zsh, PowerShell — init-check script'leri)
- Markdown (rules/, skills/ tanımları)
- JSON (plugin.json, hooks.json, marketplace.json)

## Dil

Türkçe iletişim, İngilizce kod yorumu ve commit mesajları.

## Yapı

- `.claude-plugin/plugin.json`, `marketplace.json` — plugin ve marketplace tanımları
- `hooks/hooks.json` — SessionStart hook'ları (kural yükleme, init-check)
- `rules/` — 13 kural dosyası (oturum başı `~/.claude/rules/` altına materialise edilir)
- `skills/` — `commit`, `extension-builder`, `project-init`, `obsidian-init`, `obsidian-note`, `obsidian-audit`, `obsidian-recall`, `obsidian-search`, `obsidian-doc-source`, `crawl2md`, `worktree`
- `agents/` — alt agent'lar (obsidian-initializer, obsidian-writer, obsidian-searcher, stack-detector, arch-mapper vb.)
- `scripts/` — `load-rules.sh`, `init-check.sh`, `init-check.ps1`, `setup.py`
- `commands/`, `bin/` — ek genişletme noktaları

## Entegrasyonlar (CLI / MCP)

- `plane-cli` — görev/proje yönetimi (CLI binary; CLAUDE.local.md'de Plane proje UUID, env'de `PLANE_URL`/`PLANE_API_KEY`/`PLANE_WORKSPACE_SLUG`)
- `solo` — process yönetimi (CLI binary, HTTP control plane; bu plugin repo'su için çalışan process yok)
- `obsidian` — vault okuma/yazma CLI (proje belleği)
- `ctx7` — kütüphane dokümantasyonu CLI
- `whatsapp` — MCP server (mesajlaşma; `user-message` skill'inin gönderim entegrasyonu)

## Kod Konvansiyonları

- Shell: POSIX uyumlu, `set -e` ile fail-fast
- Markdown: başlıklar `#`, liste `-`, kod blokları ``` üçlü
- JSON: 2-space indent
- Commit: conventional commits (`feat:`, `fix:`, `chore:`, `docs:`)

## Versiyon Akışı

- `plugin.json` ve `marketplace.json` içindeki version aynı tutulur
- Commit mesajında `(vX.Y.Z)` soneki kullanılır

## Komutlar

```bash
# Kural dosyalarını ~/.claude/rules/ altına materialise et
bash scripts/load-rules.sh

# Init-check (proje yapılandırma eksik mi)
bash scripts/init-check.sh

# Windows karşılığı
pwsh scripts/init-check.ps1

# Setup (Python)
python scripts/setup.py
```

## Test

Plugin manuel test edilir — yeni oturum açıp hook çıktısını gözle.

## Notlar

- `rules/` değişirse plugin versiyonu bump edilir
- `skills/` klasöründe her skill'in kendi `SKILL.md` dosyası olur
- Yeni kural eklerken `hooks/hooks.json` içindeki `load-rules.sh` otomatik kopyalar

## Tanıtım Sitesi Senkronu (docs/index.html)

`docs/index.html` GitHub Pages tanıtım sitesidir (https://omert11.github.io/personal-assistant/) ve plugin'in **rules / hooks / skills / agents / bağımlılıkları** tek tek anlatır.

**Kural**: `rules/`, `hooks/`, `skills/`, `agents/` veya bağımlılık yapısı (setup.py'deki MCP'ler) **değiştiğinde**, `docs/index.html` içindeki ilgili bölüm de aynı commit'te güncellenmelidir — site bayatlamasın. Yeni bir skill/agent/hook/rule eklenince siteye kartı eklenir, biri kaldırılınca silinir, davranışı değişince açıklaması güncellenir.

`commit` skill'i bu uyumu rules-uyum kontrolünde gözetir: bu dosyalar değiştiyse "docs/index.html güncellendi mi?" diye değerlendirir, gerekiyorsa bulgu olarak sunar.
