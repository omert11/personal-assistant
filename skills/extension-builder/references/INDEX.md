# Claude Code Resmi Döküman URL Haritası

Tüm URL'ler `https://code.claude.com/docs/en/<page>.md` formatında. **Önemli:** `.md` uzantısı eklenince Mintlify ham markdown döndürür (HTML değil) — WebFetch için ideal, token yarısı kadar. Extension yazımına başlamadan önce ilgili sayfayı **WebFetch ile çek**, kendi belleğinden uydurma.

## Kullanım Talimatı

1. Skill ne yazacağını bilince, ihtiyaç duyduğu konuları aşağıdaki listeden seç
2. Her biri için `WebFetch(url, "what schema/fields does X need?")` çağır
3. Cevap geldikten sonra extension'ı yaz
4. Asla "muhtemelen şöyle" demeyerek kendi belleğinden alan/schema uydurma

## URL Haritası

### Skill, Plugin, Hook Yazımı (en kritik)

| Konu | URL |
|------|-----|
| Skills (frontmatter, supporting files, invocation) | https://code.claude.com/docs/en/skills.md |
| Plugins (oluşturma, scope, namespace) | https://code.claude.com/docs/en/plugins.md |
| Plugins reference (tam manifest schema, CLI) | https://code.claude.com/docs/en/plugins-reference.md |
| Hooks guide (tutorial, kullanım örnekleri) | https://code.claude.com/docs/en/hooks-guide.md |
| Hooks reference (tüm event'ler, JSON schema) | https://code.claude.com/docs/en/hooks.md |

### Subagent ve Team

| Konu | URL |
|------|-----|
| Subagents (frontmatter, scope, hooks, memory) | https://code.claude.com/docs/en/sub-agents.md |
| Agent teams (deneysel, çoklu Claude) | https://code.claude.com/docs/en/agent-teams.md |

### MCP ve Channel

| Konu | URL |
|------|-----|
| MCP (transport, scope, OAuth, tool search) | https://code.claude.com/docs/en/mcp.md |
| Channels reference (push notifications, reply tool) | https://code.claude.com/docs/en/channels-reference.md |
| Channels usage (Telegram/Discord/iMessage) | https://code.claude.com/docs/en/channels.md |

### Marketplace ve Dağıtım

| Konu | URL |
|------|-----|
| Discover plugins (install, marketplace add) | https://code.claude.com/docs/en/discover-plugins.md |
| Plugin marketplaces (oluşturma, hosting, schema) | https://code.claude.com/docs/en/plugin-marketplaces.md |
| Plugin dependencies (semver constraints) | https://code.claude.com/docs/en/plugin-dependencies.md |

### Stilizasyon ve Davranış

| Konu | URL |
|------|-----|
| Output styles (default/explanatory/learning, custom) | https://code.claude.com/docs/en/output-styles.md |
| Memory (CLAUDE.md, lazy loading, paths) | https://code.claude.com/docs/en/memory.md |
| Permissions (modes, deny/ask rules) | https://code.claude.com/docs/en/permissions.md |
| Settings (settings.json full schema) | https://code.claude.com/docs/en/settings.md |

### Programmatic ve CI

| Konu | URL |
|------|-----|
| Headless mode / Agent SDK (claude -p) | https://code.claude.com/docs/en/headless.md |
| CLI reference (tüm flag'ler) | https://code.claude.com/docs/en/cli-reference.md |
| Scheduled tasks (/loop, cron) | https://code.claude.com/docs/en/scheduled-tasks.md |

### Diğer

| Konu | URL |
|------|-----|
| Checkpointing (/rewind, restore, summarize) | https://code.claude.com/docs/en/checkpointing.md |
| Tools reference (Bash/Edit/Read/Glob/Grep schema) | https://code.claude.com/docs/en/tools-reference.md |
| Statusline (custom statusline yazma) | https://code.claude.com/docs/en/statusline.md |
| Commands (built-in commands ve bundled skills) | https://code.claude.com/docs/en/commands.md |
| Common workflows (worktree, plan mode, vb) | https://code.claude.com/docs/en/common-workflows.md |

## Master Index (Tüm Sayfalar)

llms.txt formatında tüm Claude Code döküman sayfalarının dizini:
https://code.claude.com/docs/llms.txt

Bilmediğin bir konu için önce buradan başla.

## Library/Framework Dökümanı (Claude Code dışı)

Claude Code extension dışında bir kütüphaneye (React, Next.js, Prisma, vb.) ihtiyaç olursa:
- WebFetch yerine **`ctx7` CLI** kullan
- `npx ctx7@latest library <name> "<query>"` → `npx ctx7@latest docs <libraryId> "<query>"`
- Context7 Claude Code dökümanı için **uygun değil**, sadece npm/library için
