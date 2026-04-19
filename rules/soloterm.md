# SoloTerm

- Proje ID `CLAUDE.local.md` içinden alınır
- Solo MCP araçları (`mcp__solo__*`) üzerinden process yönetimi yapılır
- Tekrar eden shell komutları için mutlaka `solo.yml` oluşturulmalı ve komutlar buraya eklenmeli
- Bir komut çalıştırılacaksa ve ileride tekrar kullanılabilecekse: önce `solo.yml`'yi kontrol et, komut varsa Solo üzerinden çalıştır, yoksa önce `solo.yml`'ye ekle sonra Solo üzerinden çalıştır
- `solo.yml` ile tanımlanan komutlar MCP üzerinden başlatılabilir, durdurulabilir, yeniden başlatılabilir ve çıktıları takip edilebilir

## solo.yml Formatı

```yaml
name: proje-adi
icon: null               # Max 256 KB, proje klasöründe, PNG/JPG/GIF/ICO/WebP veya inline SVG
processes:
  process-adi:
    command: shell komutu
    working_dir: /opsiyonel/calisma/dizini
    auto_start: false          # Solo açılınca otomatik başlat
    auto_restart: false        # Çökünce otomatik yeniden başlat
    restart_when_changed: []   # Dosya değişikliğinde yeniden başlat
    env: {}                    # Ortam değişkenleri
```

### Örnek

```yaml
name: b2b-dmc
icon: null
processes:
  backend:
    command: cd backend/cmd/api && go build -o api-mac . && ./api-mac
    autostart: true
  frontend:
    command: cd frontend && npm run dev
    autostart: true
  admin-frontend:
    command: cd admin-frontend && npm run dev
    autostart: true
```
