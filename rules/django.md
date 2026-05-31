# Django

## F7 Çeviri Sistemi
Projede standart django/djangojs domain'lerine ek olarak `djangof7` adında özel bir çeviri domain'i var. Bu domain F7 framework'üne özel çevirileri yönetir.

- Mesaj çıkarma: `python manage.py makemessagesf7 -d djangof7 --all`
- Derleme sonrası: `python manage.py compilemessages`
- Çeviri alanlarını güncelle: `python manage.py update_translation_fields`

## Proje Yapısı
- Mobil repo her zaman Django projesi altında `./mobile/<repo-adı>/` dizininde bulunur
- Loglar: `server/logs/` altında
- Uygulama logoları: `assets/app/` altında

## Proje Kurulumu (uv)
### Python 3.11 (eski projeler)
```
uv python pin 3.11 && uv venv && uv pip install -r requirements.txt && uv pip install "setuptools<81" && uv pip install pre-commit black isort flake8 djlint git+https://github.com/omert11/dijilint.git ipykernel
```

### Python 3.13 (yeni projeler)
```
uv python pin 3.13 && uv venv && uv pip install -r requirements.txt && uv pip install "setuptools<81" && uv pip install pre-commit ipykernel && uv pip install -r requirements.dev.txt
```

## Elasticsearch Reindex Komutları
- `python manage.py elastic_reindex_hotel`
- `python manage.py elastic_reindex_flight`
- `python manage.py elastic_reindex_car`
- `python manage.py elastic_reindex_transfer`
- `python manage.py elastic_reindex_bus`
- `python manage.py elastic_reindex_tour`
- `python manage.py elastic_reindex_ferry`

## Django Admin
- Ortak kullanıcı: `<admin-user>` / `<admin-pass>` (gerçek değerler `local-rules/django.md`'de, repo'ya commit edilmez)
- NOT: Bu user genel olarak tüm projelerde ortak, ekli olabilir
- Panel (admin) template: **SmartAdmin** (Bootstrap 5, jQuery-free)
- B2C projelerde URL yapısı: Django Admin → `superadmin/`, Panel sayfaları → `admin/`
