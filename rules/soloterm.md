# SoloTerm

- Proje ID `CLAUDE.local.md` içinden alınır
- Process yönetimi `solo` **CLI** ile yapılır (`~/.local/bin/solo`, `solo --version` ile doğrula)
- Tekrar eden shell komutları için mutlaka `solo.yml` oluşturulmalı ve komutlar buraya eklenmeli
- Bir komut çalıştırılacaksa ve ileride tekrar kullanılabilecekse: önce `solo.yml`'yi kontrol et, komut varsa Solo üzerinden çalıştır, yoksa önce `solo.yml`'ye ekle sonra Solo üzerinden çalıştır
- `solo.yml` ile tanımlanan komutlar CLI üzerinden başlatılabilir, durdurulabilir, yeniden başlatılabilir ve çıktıları takip edilebilir

## CLI Kullanımı

CLI HTTP control plane'e (Solo app) bağlanır — app açık olmalı. Her komutta `--json` ile makine-okunur çıktı al, parse et. `solo doctor` ile bağlantıyı doğrula.

```bash
solo --version                          # kurulu mu (0.7.x)
solo doctor                             # CLI + HTTP API bağlantı kontrolü
solo status --json                      # app durumu
```

### Proje

```bash
solo projects list --json               # tüm projeler (id, name, path)
solo projects get <id> --json
solo projects create <name> <path> --json
solo projects rename <id> <display-name> --json
solo projects delete <id> [--confirm-stop-running] --json
```

> Proje ID `CLAUDE.local.md`'deki `Solo ID`'den alınır. Yoksa `projects list --json` çıktısında `path` ile eşleştir.

### Process

```bash
solo processes list --project-id <id> --json
solo processes get <id> --json
solo processes spawn --project-id <id> --kind terminal [--name <name>] --json
solo processes start <id> --json
solo processes stop <id> --json
solo processes restart <id> --json
solo processes rename <id> <new-name> --json
```

### Commands (solo.yml process'leri toplu)

```bash
solo commands start-all   --project-id <id> --json   # solo.yml'deki tüm trusted komutları başlat
solo commands stop-all    --project-id <id> --json
solo commands restart-all --project-id <id> --json
```

### Todos / Scratchpads

```bash
solo todos list   --project-id <id> --json
solo todos create --project-id <id> --title <title> [--body <body>] [--priority <p>] [--tag <t> ...] --json
solo todos complete <id> --project-id <id> --json

solo scratchpads list   --project-id <id> --json
solo scratchpads read   <id> --project-id <id> [--mode full|content|headings|section] --json
solo scratchpads append <id> --project-id <id> --content <text> --json
```

> Tüm komutlar için: `solo --help`. JSON çıktı `{ok, command, data}` zarfında döner.

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
