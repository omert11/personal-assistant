# Browser & Frontend Testing

## Tercih Sirasi

- Tarayici otomasyonu ve frontend testi icin **Playwright CLI** (`playwright-cli`) kullan
- `playwright-cli` skill'i otomatik aktif (`~/.claude/skills/playwright-cli/`)
- MCP tabanli playwright **kaldirildi** — CLI token-efficient ve coding agent'lar icin Microsoft tarafindan onerilen yol

## Kullanim

CLI'yi `Bash` tool ile cagir:

```bash
playwright-cli open https://example.com         # tarayici ac
playwright-cli snapshot                          # element ref'leri al
playwright-cli click e15                         # ref ile tikla
playwright-cli fill e20 "kullanici" --submit     # input doldur + Enter
playwright-cli screenshot                        # ekran goruntu
playwright-cli close                             # kapat
```

Detayli komut listesi: `playwright-cli --help` veya `~/.claude/skills/playwright-cli/SKILL.md`.

## Session Yonetimi

- Default: in-memory profil, browser kapaninca kayboluyor
- `--persistent` ile diske kaydet
- `-s=<name>` ile multi-session: farkli projeler icin ayri tarayici

```bash
PLAYWRIGHT_CLI_SESSION=todo-app playwright-cli open https://demo.playwright.dev/todomvc
playwright-cli list                      # aktif session'lar
playwright-cli close-all                 # hepsini kapat
playwright-cli show                      # gorsel dashboard
```

## Ne Zaman Playwright CLI

- AI agent ile web scraping / otomasyon
- Frontend testi ve assertion'lar
- CI/CD pipeline testleri
- Coklu tarayici destegi (Chrome, Firefox, WebKit)
- Snapshot + ref tabanli element interaction (a11y tree token cost yok)

## Test Suite Yazma

`@playwright/test` framework'u ayri urun — pytest/jest gibi. CLI tek-shot otomasyon icin, test suite icin `npx playwright test` veya proje icindeki `playwright.config.ts` kullan.
