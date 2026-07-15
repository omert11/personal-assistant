# Django

## Template Yorumları — `{% comment %}` ZORUNLU

## CSRF Token — Full Page Cache (ZORUNLU)
Projede full page cache varsa (`cache_page` / `PageSetupLoaderMixin`) cache key'de session/user yoktur → HTML'e gömülü csrf token bayat kalır, POST **403** verir. Cookie tazedir (middleware her istekte `get_token` çağırır); bozuk olan **sadece hidden input**.

**YASAK**: cache'lenen sayfada çıplak `{% csrf_token %}`.

**ZORUNLU** — sıraya uy, üst madde uyuyorsa alta İNME:
1. Form: projenin csrf-inject attribute'unu ekle (voyante: `user-utils-add-csrf-submit`). Başka hiçbir şey yazma.
2. AJAX: projenin ajax helper'ını kullan (voyante: `dijiApp.ajax`). `X-CSRFToken` elle yazma, otomatik gider.
3. İkisi de yoksa: cookie okuyup `X-CSRFToken` basan JS helper yaz.

PWA helper'ı CSRF eklemeyebilir (token-auth varsayımı — voyante `dijiapp.utils.ajax`). Session-auth view'a POST atıyorsan header'ı elle geçmek ZORUNLU.

Tek istisna: cache'lenmeyen sayfalar (panel/login-gated) — orada `{% csrf_token %}` bırak.

## F7 Çeviri Sistemi
Projede standart django/djangojs domain'lerine ek olarak `djangof7` adında özel bir çeviri domain'i var. Bu domain F7 framework'üne özel çevirileri yönetir. `python manage.py makemessagesf7 -d djangof7 --all`

## Proje Yapısı
- Mobil repo her zaman Django projesi altında `./mobile/<repo-adı>/` dizininde bulunur
- Loglar: `server/logs/` altında
- Uygulama logoları: `assets/app/` altında

## Deploy Tetikleme
Django projelerinde pr merge olduğunda deploy tetiklenir ve sunucuda tüm işlemler otomatik yapılır ek işlem gerekmez. (Django dışı projelere genelleme yapma — deploy tetikleyicisi repo'nun `.github/workflows/*.yml` `on:` bloğundan doğrulanır.)

## Proje Kurulumu (uv)
### Python 3.11 (eski projeler)
```
uv python pin 3.11 && uv venv && uv pip install -r requirements.txt && uv pip install "setuptools<81" && uv pip install pre-commit black isort flake8 djlint git+https://github.com/omert11/dijilint.git ipykernel
```

### Python 3.13 (yeni projeler)
```
uv python pin 3.13 && uv venv && uv pip install -r requirements.txt && uv pip install "setuptools<81" && uv pip install pre-commit ipykernel && uv pip install -r requirements.dev.txt
```


- Panel (admin) template: **SmartAdmin** (Bootstrap 5, jQuery-free)
- B2C projelerde URL yapısı: Django Admin → `superadmin/`, Panel sayfaları → `admin/`

## Mobil Publish — Domain Pre-Flight (ZORUNLU, TÜM PROJELER)
Her Django projesinin mobil app'i (Framework7 / Capacitor) bir **backend domain'ine** bağlanır.
Bu domain genelde tek bir JS dosyasında hardcoded tutulur ve geliştirme sırasında dev/stage/localhost'a
çevrilir. **Geliştirici prod'a geri çevirmeyi unutursa, dev backend'ine bağlı bir release store'a sızar**
(canlı vaka: Zenrota `app.js` 9 Haziran'da dev'e çevrilmiş, prod'a alınmamış → müşteri dev DB içeriği görmüş).

### Kural — Publish/Release Öncesi Bloklayıcı Kontrol
**Domain tanımını bul** — yaygın konum `mobile/<app>/src/js/core/app.js` içindeki `window.domain_name`
**Kullanıcı "aksini söylemediği sürece domain MUTLAKA prod olmalı"** - Prod işareti: `https://www.<marka>.com` / `https://<marka>.com` 