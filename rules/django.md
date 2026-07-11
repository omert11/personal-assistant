# Django

## Template Yorumları — `{% comment %}` ZORUNLU

## F7 Çeviri Sistemi
Projede standart django/djangojs domain'lerine ek olarak `djangof7` adında özel bir çeviri domain'i var. Bu domain F7 framework'üne özel çevirileri yönetir. `python manage.py makemessagesf7 -d djangof7 --all`

## Proje Yapısı
- Mobil repo her zaman Django projesi altında `./mobile/<repo-adı>/` dizininde bulunur
- Loglar: `server/logs/` altında
- Uygulama logoları: `assets/app/` altında

## Deploy Tetikleme
pr merge olduğunda deploy tetiklenir ve sunucuda tüm işlemler otomatik yapılır ek işlem gerekmez

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