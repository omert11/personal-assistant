# Ağır Derlemeler — Tek Sıra (heavy)

Makinede (M1 Pro, 8 çekirdek / 16 GB) aynı anda birden fazla ağır derleme koşunca — özellikle
farklı projelerde paralel Claude oturumları varken — CPU ve bellek sıkışır, hepsi birden yavaşlar.
Çözüm: **ağır derlemeler proje ve dil fark etmeksizin tek global kilitte sıraya girer.**

## `heavy` Sarmalayıcı

```bash
heavy cargo build -p pingr     # kilit boşsa hemen koşar, doluysa sırada bekler
heavy go build ./...           # cargo derliyorsa bekler
heavy --low cargo tauri dev    # kilide GİRMEZ, arka plan QoS'unda koşar
heavy --status                 # kilidi kim tutuyor (komut + pid + cwd)
```

- Kilit: `~/.cache/heavy-build.lock`, `/usr/bin/lockf` ile (`flock` macOS'ta yok).
- Tutan süreç `~/.cache/heavy-build.current` dosyasına yazılır — bekleyen neyi beklediğini görür.
- Bekleme tavanı `HEAVY_TIMEOUT` (varsayılan 1200 s). Tavan aşılırsa komut **çalıştırılmaz**,
  çıkış kodu 75 olur — takılan bir derleme herkesi süresiz kilitlemesin.
- Kaynak: `personal-assistant/scripts/heavy.sh`; oturum başında `~/.local/bin/heavy` symlink'i kurulur.

## Katman 1 — Claude PreToolUse Hook (otomatik)

`scripts/heavy-guard.sh` her Bash çağrısını süzer, `updatedInput` ile komutu yeniden yazar:

| Komut sınıfı | Ne olur |
|---|---|
| `cargo build/test/check/clippy/bench/doc/install`, `cargo tauri build`, `go build/test/vet/install/generate`, `npm\|pnpm\|yarn\|bun run build`, `next\|vite\|tsc\|turbo\|webpack\|esbuild build`, `xcodebuild`, `gradle`, `cmake --build`, `docker build`, `maturin build` | `heavy bash -c '<komut>'` + **run_in_background: true** |
| `cargo run/watch`, `cargo tauri dev`, `go run`, `air`, `npm/pnpm/yarn/bun run dev\|start\|watch`, `next dev`, `vite`, `nodemon`, `manage.py runserver` | `heavy --low bash -c '<komut>'` (kilit yok) |
| `cargo tree/metadata/fmt`, `go env/list/fmt`, diğer her şey | dokunulmaz |

Ağır derlemeler **zorunlu olarak arka plana alınır**: kilit beklemesi Bash tool'un 10 dakikalık
tavanını aşabilir. Sonuç bittiğinde bildirim gelir, çıktı ondan sonra okunur.

Zaten `heavy` / `lockf` / `taskpolicy` içeren komutlar es geçilir — çift sarmalama olmaz.

Desen değiştirmek gerekirse `~/.config/heavy/patterns.sh` içinde `HEAVY_RE` / `DEV_RE` yeniden
tanımlanır (hook varsa onu okur); plugin güncellemesi bu dosyayı ezmez.

## Katman 2 — solo.yml (elle)

Solo'dan başlatılan derleme komutları **`heavy` ile yazılır**; uzun ömürlü dev sunucuları
`heavy --low` ile:

```yaml
processes:
  - name: Build
    command: heavy cargo build -p pingr
  - name: Dev
    command: heavy --low cargo tauri dev
```

Yeni bir `solo.yml` komutu eklerken bu sarmalama unutulmaz.

## Kapsam Dışı

Kullanıcının kendi terminalinden elle çalıştırdığı komutlar guard'a girmez — orada `heavy`
elle yazılır. PATH shim (`~/.local/bin/cargo`) bilinçli olarak **kurulmadı**: `cargo tree`,
`go env` gibi anlık komutları da yakalayıp kırılganlık üretiyor.

## Neden Kilide Dev Sunucusu Alınmaz

`cargo tauri dev` / `air` / `runserver` derleyip **saatlerce** koşar. Kilide dahil edilirse
kilidi o süre boyunca tutar ve guard'ın kendisi tıkanma sebebi olur. Onun yerine
`taskpolicy -b` ile arka plan QoS'una alınır: bloklamaz, CPU'yu ön plandaki derlemeye bırakır.
