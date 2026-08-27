# Browser & Frontend Testing

## Tercih Sirasi
- Tarayici otomasyonu ve frontend testi icin **Playwright CLI** (`playwright-cli`) kullan
- `playwright-cli` skill'i otomatik aktif (`~/.claude/skills/playwright-cli/`)
- `playwright-cli` skill'i cagrildiginda `playwright-best-practices` skill'i de cagrilir — CLI yuzeyi
  ile dogru Playwright pratigi (locator, assertion/bekleme, POM, fixture, mock, CI, flake) ayri
  dosyalarda; ikisi birlikte okunur. Bag skill icine gomulu (`setup.py` her kurulumda yeniden uygular).

## Ne Zaman Playwright CLI
- AI agent ile web scraping / otomasyon
- Frontend testi ve assertion'lar
- CI/CD pipeline testleri
- Coklu tarayici destegi (Chrome, Firefox, WebKit)
- Snapshot + ref tabanli element interaction (a11y tree token cost yok)

## Test Suite Yazma
`@playwright/test` framework'u ayri urun — pytest/jest gibi. CLI tek-shot otomasyon icin, test suite icin `npx playwright test` veya proje icindeki `playwright.config.ts` kullan.
