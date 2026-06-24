# Django

## Template Yorumları — `{% comment %}` ZORUNLU

Django template (`.html`) dosyalarında yorum için **`{# ... #}` KULLANMAK YASAK**, her zaman `{% comment %} ... {% endcomment %}` kullanılır. `{# #}` çok satıra yayıldığında veya içinde `#}`, `{{`, `{%` gibi karakterler geçtiğinde parser yorumu erken kapatır ve render hatası verir. `{% comment %}` içeriği ham metin sayar (içindeki etiketler parse edilmez) ve HTML çıktısına sızmaz.

```django
{% comment %}
açıklama buraya — çok satır, özel karakter sorun değil
{% endcomment %}
```

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
> UYARI: Komut isimleri projeden projeye DEĞİŞEBİLİR (özellikle hotel). Çalıştırmadan önce
> mutlaka `find . -path "*/management/commands/*.py" | grep -i reindex` ile gerçek isimleri doğrula.
- `python manage.py elastic_reindex_flight`
- `python manage.py elastic_reindex_car`
- `python manage.py elastic_reindex_bus`
- `python manage.py elastic_reindex_tour`
- `python manage.py elastic_reindex_ferry`
- Hotel: `elastic_reindex_hotel` VEYA `elasticsearch_reindex_hotel` (prefix projeye göre değişir — voyante-web'de `elasticsearch_` prefix'li)
- Transfer: `elastic_reindex_transfer` (her projede yok — voyante-web'de mevcut DEĞİL)
- Lokasyon arama indeksi (varsa): `python manage.py update_location_search`

## Django Admin
- Ortak kullanıcı: `<admin-user>` / `<admin-pass>` (gerçek değerler `local-rules/django.md`'de, repo'ya commit edilmez)
- NOT: Bu user genel olarak tüm projelerde ortak, ekli olabilir
- Panel (admin) template: **SmartAdmin** (Bootstrap 5, jQuery-free)
- B2C projelerde URL yapısı: Django Admin → `superadmin/`, Panel sayfaları → `admin/`

## Mobil Publish — Domain Pre-Flight (ZORUNLU, TÜM PROJELER)

Her Django projesinin mobil app'i (Framework7 / Capacitor) bir **backend domain'ine** bağlanır.
Bu domain genelde tek bir JS dosyasında hardcoded tutulur ve geliştirme sırasında dev/stage/localhost'a
çevrilir. **Geliştirici prod'a geri çevirmeyi unutursa, dev backend'ine bağlı bir release store'a sızar**
(canlı vaka: Zenrota `app.js` 9 Haziran'da dev'e çevrilmiş, prod'a alınmamış → müşteri dev DB içeriği görmüş).

### Kural — Publish/Release Öncesi Bloklayıcı Kontrol

Bir mobil app publish/release/build işlemine başlamadan **ÖNCE** (App Store, Google Play, Huawei,
TestFlight, AAB/IPA/APK build, `fastlane`, `bundleRelease`, `npm run build-and-copy-*` vb.):

1. **Domain tanımını bul** — yaygın konum `mobile/<app>/src/js/core/app.js` içindeki `window.domain_name`,
   ama projeye göre değişir. Bulmak için:
   ```bash
   grep -rn "domain_name\|API_URL\|baseURL\|base_url" mobile/*/src/js 2>/dev/null | grep -v node_modules
   ```
2. **Aktif (yorum olmayan) değeri kontrol et** — prod domain mi?
   - Prod işareti: `https://www.<marka>.com` / `https://<marka>.com` (localhost/`192.168`/`*dev*`/`*stage*`/`*.diji.app` DEĞİL)
3. **Prod DEĞİLSE → DUR.** `AskUserQuestion` ile uyar (header: "Domain", question: "Mobil app domain'i
   prod değil (`<aktif değer>`). Release prod domain'ine çevrilmeli. Ne yapayım?",
   options: ["Prod'a çevir ve devam", "Bilerek dev/stage — devam et", "İptal"]).
   **Kullanıcı onaylamadan publish'e devam etme.**
4. **Kullanıcı "aksini söylemediği sürece domain MUTLAKA prod olmalı"** — varsayılan davranış prod'a çevirmek;
   dev/stage ile yayın ancak kullanıcı açıkça isterse.

> Bu kural **app-publisher / app-store-mcp** akışları ve manuel `fastlane`/`gradlew` publish'lerinin
> hepsinde geçerlidir. Domain dosyasının yolu/değişken adı projeden projeye değişir — önce grep ile doğrula.
