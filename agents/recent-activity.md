---
name: recent-activity
description: Son 30 commit'i analiz ederek proje içinde popüler/aktif alanları tespit eden alt agent. obsidian-initializer orchestrator tarafından çağrılır. Hot area, popüler dosyalar, contributor listesi döner.
tools: Bash, Read
model: haiku
---

# Recent Activity

Git geçmişini analiz eder, son dönemin aktif alanlarını haritalar.

## Akis

1. `git log -30 --pretty=format:'%h|%an|%ad|%s' --date=short` ile son 30 commit
2. `git log -30 --name-only --pretty=format:''` ile değişen dosyalar
3. Dosya frekansı say (aynı dosya kaç commit'te değişti)
4. Top-level klasör frekansı say (backend/, frontend/ hangi daha aktif)
5. Contributor frekansı

## Rapor Formati

```markdown
## Son Aktivite (Son 30 Commit)

### Hot Areas

| Klasör | Commit |
|--------|--------|
| backend/apps/booking | 12 |
| frontend/src/pages | 8 |
| mobile | 3 |

### En Çok Değişen Dosyalar

- `backend/apps/booking/views.py` (6 commit)
- `frontend/src/pages/booking.tsx` (4 commit)
- ...

### Son 30 Commit (Başlıklar)

- `fix: payment callback race condition` — 2026-04-18
- `feat: add hotel filter` — 2026-04-15
- ...

### Aktif Contributorlar

- Omer Faruk Yigin (24 commit)
- ... (6 commit)
```

Git repo değilse "Git repo değil" dön. 30 commit'ten az varsa mevcut kadarıyla çalış.
