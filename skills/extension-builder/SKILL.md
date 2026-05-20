---
name: extension-builder
description: Claude Code için skill/plugin/agent/hook/MCP/output-style/channel/marketplace yazar.
when_to_use: Trigger — "skill yaz", "plugin oluştur", "hook ekle", "MCP server yap", "agent tanımla", "marketplace oluştur", "channel yaz", "output style ekle", "extension oluştur", "claude code'u genişlet". Resmi dökümanı WebFetch ile çeker, schema uydurmaz.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch, AskUserQuestion
---

# Claude Code Extension Builder

Bu skill kullanıcıya Claude Code için **skill, plugin, agent, hook, MCP server, output style, channel veya marketplace** yazmasında yardım eder.

## Temel Kural

**Asla schema/alan isimlerini bellekten uydurma.** Her zaman `references/INDEX.md`'deki URL haritasından ilgili dökümanı **WebFetch ile çek**.

URL formatı: `https://code.claude.com/docs/en/<page>.md`

`.md` uzantısı eklenince Mintlify ham markdown verir — HTML parsing yok, token yarısı kadar.

## İş Akışı

### Adım 1: Ne Yazıldığını Netleştir

Kullanıcının net olmadığı durumda `AskUserQuestion` ile sor:

- **header**: "Tip"
- **question**: "Ne oluşturmak istiyorsun?"
- **options**:
  - "Skill" — `/komut` ile çağrılan playbook
  - "Plugin" — Birden fazla bileşeni paketleyen dağıtılabilir paket
  - "Agent" — İzole context'te çalışan uzman subagent
  - "Hook" — Olay tetiklemeli script (PostToolUse, SessionStart vb.)
  - "MCP Server" — Dış servis entegrasyonu (Slack, DB vb.)
  - "Output Style" — Claude'un yanıt tonu/formatı
  - "Channel" — Push notification yapan MCP server
  - "Marketplace" — Plugin dağıtım kataloğu

### Adım 2: Resmi Dökümanı Çek

Tipe göre `references/INDEX.md`'den ilgili URL'i bul ve `WebFetch` ile çek:

| Tip          | URL'ler                                                                                |
| :----------- | :------------------------------------------------------------------------------------- |
| Skill        | `skills.md`                                                                            |
| Plugin       | `plugins.md` + `plugins-reference.md`                                                  |
| Agent        | `sub-agents.md`                                                                        |
| Hook         | `hooks-guide.md` + `hooks.md` (reference)                                              |
| MCP Server   | `mcp.md` + (gerekirse channels-reference.md)                                           |
| Output Style | `output-styles.md`                                                                     |
| Channel      | `channels-reference.md`                                                                |
| Marketplace  | `plugin-marketplaces.md`                                                               |

WebFetch prompt örneği:
```
WebFetch(
  url: "https://code.claude.com/docs/en/skills.md",
  prompt: "List all SKILL.md frontmatter fields with their types, defaults, and which are required. Include description string substitutions like $ARGUMENTS."
)
```

### Adım 3: Detayları Topla

`AskUserQuestion` ile (max 4 soru, gerekirse art arda):

1. **Konum**:
   - "Personal Plugin (`~/Desktop/Git/personal-assistant`)" — paylaşılır, version'lı
   - "User-level (`~/.claude/skills/<name>/`)" — kişisel, tüm projeler
   - "Project-level (`.claude/skills/<name>/`)" — sadece bu proje
2. **İsim**: kebab-case
3. **Açıklama**: tetikleme örnekleriyle
4. **İhtiyaç duyulan tool'lar / MCP'ler**

### Adım 3.5: Frontmatter Karakter Limiti (ZORUNLU)

Yeni skill yazarken:

- `description` **max 75-100 karakter** — tek cümle, "ne yapar" anlatır
- Trigger phrase listesi, koşul, "kullanıcı şunu derse" detayı **`when_to_use`** alanına yazılır (format: `Trigger — "...", "...". <ek koşul>`)
- description'a trigger gömme — Claude'un skill listing budget'ı (1,536 char) içinde daha çok skill yer tutar

Örnek doğru frontmatter:

```yaml
---
name: my-skill
description: Webhook gelen payload'ı parse edip Slack'e özetler.
when_to_use: Trigger — "webhook gelirse", "payload özetle", "/my-skill". Sadece Slack entegrasyonu aktifse çalışır.
allowed-tools: Read, Bash
---
```

Yanlış (eski stil):

```yaml
description: Webhook gelen payload'ı parse edip Slack'e özetler. Kullanıcı "webhook gelirse", "payload özetle" veya "/my-skill" dediğinde tetiklenir. Sadece Slack entegrasyonu aktifse çalışır...
```

### Adım 4: Dosya Yapısını Oluştur

Dökümandan çıkardığın schema'ya birebir uy. Örnek skill için:

```
<konum>/<isim>/
├── SKILL.md           # Frontmatter + body
├── references/        # (opsiyonel) Detaylı doküman
└── scripts/           # (opsiyonel) Yardımcı script
```

Plugin için:
```
<plugin-root>/
├── .claude-plugin/plugin.json   # Manifest (KRİTİK: components .claude-plugin/'in DIŞINDA olmalı)
├── skills/<name>/SKILL.md
├── agents/<name>.md
├── hooks/hooks.json
├── .mcp.json
└── scripts/
```

### Adım 5: Personal-Assistant Plugin'e Ekleniyorsa

Eğer kullanıcı `personal-assistant` plugin'i seçtiyse:

1. `~/Desktop/Git/personal-assistant/.claude-plugin/plugin.json` dosyasını **Read** et
2. `version` alanını semver kuralına göre bump et:
   - Bug fix: PATCH (1.0.0 → 1.0.1)
   - Yeni skill/agent/hook eklendi: MINOR (1.0.0 → 1.1.0)
   - Mevcut bir bileşen breaking change: MAJOR (1.0.0 → 2.0.0)
3. **Edit** ile version'ı güncelle
4. Yeni bileşeni doğru klasöre yaz (skills/, agents/, hooks/, .mcp.json)

### Adım 6: Test Komutunu Söyle

Konuma göre:

- **Plugin**: `/plugin marketplace add ~/Desktop/Git/personal-assistant` (ilk kez) → `/plugin install personal-assistant` → `/reload-plugins`
- **User/Project skill**: Otomatik yüklenir (live change detection). Test: `/<skill-name>`
- **Hook**: `/hooks` ile menüden doğrula
- **MCP**: `claude mcp list`
- **Agent**: `/agents`

### Adım 7: Vikunja Görev Önerisi

Eğer projede Vikunja entegrasyonu varsa (`CLAUDE.local.md`'de proje ID), `AskUserQuestion` ile:
- header: "Vikunja"
- question: "Bu extension için Vikunja görevi oluşturayım mı?"
- options: ["Evet", "Hayır"]

## Kritik Hatırlatmalar

### Plugin Klasör Yapısı
**`commands/`, `agents/`, `skills/`, `hooks/` klasörleri `.claude-plugin/`'in İÇİNE değil, plugin root'una konur.** `.claude-plugin/` içinde sadece `plugin.json` olur.

### CLAUDE_PLUGIN_ROOT vs CLAUDE_PLUGIN_DATA
- `${CLAUDE_PLUGIN_ROOT}` — Plugin'in install dizini, **update ile değişir**, dosya yedek saklamak için **uygun değil**
- `${CLAUDE_PLUGIN_DATA}` — Persistent data dizini, plugin update'lerini sağ kalan dosyalar için (node_modules, cache, vb.)

### Skill Description Limit
`description` + `when_to_use` toplamı **1,536 karakterde kesilir**. Anahtar tetikleme cümlelerini başa al.

### Hook Type Seçimi
- `command` — Shell script çalıştır (en yaygın)
- `http` — HTTP POST endpoint'e yolla
- `prompt` — Tek atış LLM kararı (`{ok: true/false}`)
- `agent` — Çok turlu agentic verifier (tool kullanabilir)

### MCP Transport Seçimi
- `stdio` — Local subprocess (en yaygın, güvenli)
- `http` — Cloud servis (önerilen remote için)
- `sse` — DEPRECATED, kullanma

### Channel Capability
İki yönlü chat için: hem `claude/channel` hem `tools` capability lazım. Sender gating **şart** (prompt injection koruması).

### Subagent Limitations (Plugin İçinde)
Plugin'le gelen agent'lar `hooks`, `mcpServers`, `permissionMode` field'larını destekleMEZ. Bunlar güvenlik nedeniyle ignore edilir.

## Master Index

Bilmediğin bir konu için: `https://code.claude.com/docs/llms.txt` çek, tüm sayfaların listesi orada.

Detaylı URL haritası: [references/INDEX.md](references/INDEX.md)

## Kütüphane Dokümanı (Claude Code Dışı)

Kullanıcı Claude Code dışı bir library/framework için yardım isterse (React, Next.js, vb.), WebFetch yerine **`ctx7` CLI** kullan:
- `npx ctx7@latest library <name> "<query>"` → `/org/project` formatında ID al
- `npx ctx7@latest docs <libraryId> "<query>"` → Dokümana sorgu at
