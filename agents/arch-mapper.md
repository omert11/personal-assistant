---
name: arch-mapper
description: Projenin mimari yapısını (top-level dizinler, backend/frontend/admin ayrımı, katmanlar) haritalayan alt agent. obsidian-initializer orchestrator tarafından çağrılır. Directory tree + ana modülleri rapor eder.
tools: Read, Glob, Grep, Bash
model: haiku
---

# Arch Mapper

Proje dizin yapısını analiz eder, mimari haritayı çıkarır.

## Akis

1. Top-level klasörleri listele (`ls -d */` veya Glob `*/`)
2. Her klasör için:
   - İçindeki başlıca dosya tiplerini say (.py, .go, .tsx vb.)
   - İsimden rol tahmini: `backend`, `frontend`, `admin-frontend`, `mobile`, `api`, `cmd`, `internal`, `pkg`, `server`, `client`, `docs`, `scripts`, `tests`
3. Django ise: `apps/` altındaki Django app'lerini listele
4. Monorepo ise: workspace paketlerini tespit et

## Rapor Formati

```markdown
## Architecture

### Top-Level Yapı

- `backend/` — Django API (45 .py dosyası)
- `frontend/` — Next.js client (120 .tsx dosyası)
- `admin-frontend/` — React admin panel
- `mobile/` — Flutter app
- `docs/` — Markdown dokümantasyon

### Backend Katmanlari (Django)

- `apps/booking/` — Booking modülü
- `apps/flight/` — Flight modülü
- ...

### Notable Files

- `Dockerfile`, `docker-compose.yml` — Containerization
- `.github/workflows/` — CI (N workflow)
```

Belirsizse ham dizin ağacını 2 seviyeye kadar yaz, yorum ekleme. Çok büyük repolar için `node_modules`, `.venv`, `dist`, `build`, `.git` klasörlerini atla.
