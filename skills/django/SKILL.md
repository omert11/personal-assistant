---
name: django
description: Diji Django projeleri için zorunlu kurallar (CSRF cache, F7 çeviri, uv kurulum, mobil publish).
when_to_use: Trigger — Django projesinde çalışırken (manage.py var), template/form/AJAX/CSRF, makemessages/çeviri, proje kurulumu, mobil release/publish, deploy. Django projelerinde oturum başı hook ile otomatik yüklenir.
---

# Django

## Template Yorumları
- Template yorumu için `{% comment %}` ZORUNLU.

## CSRF Token — Full Page Cache (ZORUNLU)
Full page cache (`cache_page` / `PageSetupLoaderMixin`) olan sayfada HTML'e gömülü csrf token bayat kalır → POST **403**. Cookie tazedir; bozuk olan sadece hidden input.

**YASAK**: cache'lenen sayfada çıplak `{% csrf_token %}`.

**ZORUNLU** — sırayla; üst madde uyuyorsa alta inme:
1. Form: projenin csrf-inject attribute'unu ekle (voyante: `user-utils-add-csrf-submit`). Başka hiçbir şey yazma.
2. AJAX: projenin ajax helper'ını kullan (voyante: `dijiApp.ajax`). `X-CSRFToken` elle yazma.
3. İkisi de yoksa: cookie okuyup `X-CSRFToken` basan JS helper yaz.

PWA helper'ı CSRF eklemeyebilir (voyante `dijiapp.utils.ajax`): session-auth view'a POST'ta header'ı elle geçmek ZORUNLU.

İstisna: cache'lenmeyen sayfalar (panel/login-gated) — `{% csrf_token %}` kalır.

## F7 Çeviri Sistemi
django/djangojs'e ek `djangof7` domain'i (F7 çevirileri): `python manage.py makemessagesf7 -d djangof7 --all`

## Proje Yapısı
- Mobil repo: `./mobile/<repo-adı>/`
- Loglar: `server/logs/`
- Uygulama logoları: `assets/app/`
- Panel (admin) template: **SmartAdmin** (Bootstrap 5, jQuery-free)
- B2C URL yapısı: Django Admin → `superadmin/`, Panel sayfaları → `admin/`

## Deploy Tetikleme
PR merge → release-bot tag + Release açar ve Dokploy'da deploy eder; elle deploy yok. PR başlığı conventional commit olmalı (bump'ı belirler). Ayrıntı ve migration kuralları: `work-diji-deploy`.

## Proje Kurulumu (uv)
### Python 3.11 (eski projeler)
```
uv python pin 3.11 && uv venv && uv pip install -r requirements.txt && uv pip install "setuptools<81" && uv pip install pre-commit black isort flake8 djlint git+https://github.com/omert11/dijilint.git ipykernel
```

### Python 3.13 (yeni projeler)
```
uv python pin 3.13 && uv venv && uv pip install -r requirements.txt && uv pip install "setuptools<81" && uv pip install pre-commit ipykernel && uv pip install -r requirements.dev.txt
```

## Mobil Publish — Domain Pre-Flight (ZORUNLU, TÜM PROJELER)
Publish/release öncesi bloklayıcı kontrol:
1. Mobil app'in (Framework7 / Capacitor) backend domain tanımını bul — yaygın: `mobile/<app>/src/js/core/app.js` içinde `window.domain_name`.
2. Kullanıcı aksini söylemedikçe domain MUTLAKA prod olmalı: `https://www.<marka>.com` / `https://<marka>.com`. Prod değilse (localhost, IP, test domaini) release etme.
