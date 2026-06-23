# Plane Project Management

Diji iş/destek takibi `support.diji.tech` üzerinde **Plane** (self-hosted, Docker compose). Deployment repo: `~/Desktop/Git/plane-diji` (remote `dijii-tech/plane-diji`, nginx + Docker, `WEB_URL=https://support.diji.tech`).

## plane-cli (Issue/Proje CRUD)
- Binary kurulu (`~/.local/bin/plane-cli`), env tanımlı. Her zaman `--json` ile çağır.
- **3 env zorunlu**: `PLANE_URL` (instance URL — `/api/v1` EKLEME), `PLANE_API_KEY` (`plane_api_...`), `PLANE_WORKSPACE_SLUG` (`diji-tech`).
- Yapabildikleri: `project`, `issue` (work item), `state`, `label`, `comment`, `cycle` (sprint), `module`, `intake` (triage inbox), `page`, `worklog`, `link`, `member`. ~70 operasyon.
- Detaylı kullanım: `plane-cli` skill'i.

## ID Semantiği — KRİTİK
Plane API **UUID tabanlı**. Çoğu komut `--project <UUID>` ister (member dışında); issue/cycle/module/state/label hep UUID alır.
- **`PROJ-123`** (human identifier) → yalnızca `issue get-id PROJ-123` kabul eder, UUID'ye çevirir.
- **Tipik akış**: Kullanıcı `PROJ-123` / proje adıyla konuşur → önce `project list` / `issue get-id` ile UUID çöz → sonra hedef komutu UUID'lerle çağır.
- Assignee/lead UUID'leri için **ANA kaynak** `member list` — kullanıcı isim/email verirse önce burada eşleştir.

## REST API / SDK ile Yönetim
CLI yetmediğinde:
- **REST**: `https://support.diji.tech/api/v1/workspaces/<slug>/...` — token header `X-API-Key: <PLANE_API_KEY>`. Trailing-slash gerektiren endpoint'lere dikkat.
- **Python SDK**: `makeplane/plane-python-sdk`.
- **MCP server**: `makeplane/plane-mcp-server`.
- **API docs**: https://developers.plane.so/api-reference/introduction

## Enum / Format Referansı
- **Priority**: `urgent`, `high`, `medium`, `low`, `none` (tam küçük harf).
- **State group**: `backlog`, `unstarted`, `started`, `completed`, `cancelled`.
- **Roller** (`member list` → `role`): Admin=20, Member=15, Guest=5.
- **Tarihler**: ISO 8601 (`2026-06-23`).
- **HTML alanları**: `comment add --comment-html`, `page create --description-html` HTML ister — düz metni `<p>...</p>` ile sar.
- **worklog**: `worklog create <dakika>` — pozitif tam sayı (dakika).

## Dikkat
- **assignee/label flag farkı**: `issue update --assignees/--labels` listeyi **değiştirir** (replace); `issue assignee/label --add/--remove` listeyi **korur** (incremental). Tek kişi eklerken `assignee` komutunu kullan.
- **DESTRUCTIVE komutlar** (create/update/delete/archive) — her zaman `AskUserQuestion` ile onay al.
- **archive kısıtı**: issue yalnızca `completed`/`cancelled` state'te arşivlenir (aksi `422`).
- Hata kodları: `404` UUID yanlış/kaynak yok, `401` token geçersiz, `403` yetki yok (Guest), `400` parametre formatı, `422` geçersiz alan değeri.
