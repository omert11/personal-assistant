# SoloTerm

> ⚠️ **GEÇİCİ — Solo MCP aktif (yarabandı).** CLI'da process çıktısı/logu olmadığı için (aşağıdaki bug) geçici olarak Solo MCP kuruldu:
> ```bash
> claude mcp add --scope user --transport stdio solo -- '/Applications/Solo.app/Contents/MacOS/mcp'
> ```
> Process logu/çıktısı gerektiğinde MCP araçlarını kullan. **Bug düzeldiğinde** (CLI `solo processes output/logs/tail` veya HTTP `/output` çalışır hale geldiğinde) bu MCP `claude mcp remove --scope user solo` ile **kaldırılacak** ve bu not silinecek.

- Proje ID `CLAUDE.local.md` içinden alınır
- Process yönetimi `solo` **CLI** ile yapılır (`~/.local/bin/solo`, `solo --version` ile doğrula)
- Tekrar eden shell komutları için mutlaka `solo.yml` oluşturulmalı ve komutlar buraya eklenmeli
- Bir komut çalıştırılacaksa ve ileride tekrar kullanılabilecekse: önce `solo.yml`'yi kontrol et, komut varsa Solo üzerinden çalıştır, yoksa önce `solo.yml`'ye ekle sonra Solo üzerinden çalıştır
- `solo.yml` ile tanımlanan komutlar CLI üzerinden başlatılabilir, durdurulabilir ve yeniden başlatılabilir (process **çıktısı/logu CLI'de YOK** — aşağıdaki uyarıya bak)

## CLI Kullanımı

CLI HTTP control plane'e (Solo app) bağlanır — app açık olmalı. Her komutta `--json` ile makine-okunur çıktı al, parse et. `solo doctor` ile bağlantıyı doğrula.

### ⚠️ Process Çıktısı/Log — CLI'de YOK

Solo CLI ve HTTP API process **loglarını/çıktısını göstermez**. Mevcut alanlar sadece: `command, id, name, pid, projectId, status, uptimeSeconds`.

- `solo processes output/logs/tail` → **yok** (unknown command)
- HTTP API `GET /api/processes/{id}` → output/log alanı **yok**, `/output` `/logs` `/tail` → **404**

**Sonuç:** Bir Solo process crash/hata verdiğinde sebebini CLI'den göremezsin. Hata teşhisi için:

1. **Solo app GUI** terminal paneli (görsel), veya
2. Komutu logla: `solo.yml`'de `command: ... 2>&1 | tee /tmp/<proc>.log` → sonra `Read`/`grep`
3. HTTP servis ise `curl` ile traceback oku (Django `DEBUG=1` ise traceback döner)
4. Tek seferlik teşhiste foreground `Bash` ile çalıştır (Solo dışı)

> NOT: Bu kısıt ileride Solo CLI'da düzeltilecek. CLI'da process output/log komutu (`solo processes output/logs/tail` veya HTTP `/output` alanı) çalışır hale geldiğinde, bu uyarının **geçersizleştiğini** kullanıcıya bildir — artık GUI/workaround gerekmiyor.

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
