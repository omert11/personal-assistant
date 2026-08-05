# Ağır Derlemeler — Sınırlı Slot (heavy)

Makinede (M1 Pro, 8 çekirdek / 16 GB) aynı anda birden fazla ağır derleme koşunca — özellikle
farklı projelerde paralel Claude oturumları varken — CPU ve bellek sıkışır, hepsi birden yavaşlar.
Çözüm: **ağır derlemeler proje ve dil fark etmeksizin ortak bir slot havuzundan geçer.**
Varsayılan **2 slot**: iki ağır derleme paralel koşar, üçüncüsü sırada bekler.

## `heavy` Sarmalayıcı

```bash
heavy cargo build -p pingr     # bos slot varsa hemen koşar, yoksa sırada bekler
heavy go build ./...           # iki derleme koşuyorsa bekler
heavy --low cargo tauri dev    # slot ALMAZ, arka plan QoS'unda koşar
heavy --status                 # hangi slot dolu, hangi komutla (pid + cwd)
HEAVY_SLOTS=1 heavy cargo test # bu koşu için tek slota düş
```

- Slot havuzu: `~/.cache/heavy-build.lock.<n>`, `/usr/bin/lockf` ile (`flock` macOS'ta yok).
  `lockf` tek dosya kilitler, bu yüzden N slot = N kilit dosyası, round-robin denenir.
- Slot sayısı `HEAVY_SLOTS` (varsayılan 2). Tek sıra istenirse `HEAVY_SLOTS=1`.
- Tutan süreç `~/.cache/heavy-build.current.<n>` dosyasına yazılır — bekleyen neyi beklediğini görür.
- Bekleme tavanı `HEAVY_TIMEOUT` (varsayılan 1200 s). Tavan aşılırsa komut **çalıştırılmaz**,
  çıkış kodu 75 olur — takılan bir derleme herkesi süresiz bloklamasın.
- Komutun kendisi 75 ile çıkarsa bu "slot dolu" ile karışmaz: iç sarmalayıcı 175'e çevirir,
  dış taraf geri 75 yapar. Aksi hâlde komut ikinci kez çalıştırılırdı.
- Kaynak: `personal-assistant/scripts/heavy.sh`; oturum başında `~/.local/bin/heavy` symlink'i kurulur.

**Slot sayısını artırmanın bedeli**: iki Rust derlemesi çakışırsa (`jobs = 6` × 2 = 12 iş) 16 GB'da
swap başlar ve sıraya almanın kazancı geri verilir. 2'nin üstüne çıkmadan önce ölçülmeli.

## Katman 1 — Claude PreToolUse Hook (otomatik)

`scripts/heavy-guard.sh` her Bash çağrısını süzer, `updatedInput` ile komutu yeniden yazar:

| Komut sınıfı | Ne olur |
|---|---|
| `cargo build/test/check/clippy/bench/doc/install`, `cargo tauri build`, `go build/test/vet/install/generate`, `npm\|pnpm\|yarn\|bun run build`, `next\|vite\|tsc\|turbo\|webpack\|esbuild build`, `xcodebuild`, `gradle`, `cmake --build`, `docker build`, `maturin build` | `heavy bash -c '<komut>'` + **run_in_background: true** |
| `cargo run/watch`, `cargo tauri dev`, `go run`, `air`, `npm/pnpm/yarn/bun run dev\|start\|watch`, `next dev`, `vite`, `nodemon`, `manage.py runserver` | `heavy --low bash -c '<komut>'` (slot almaz) |
| `cargo tree/metadata/fmt`, `go env/list/fmt`, diğer her şey | dokunulmaz |

Ağır derlemeler **zorunlu olarak arka plana alınır**: slot beklemesi Bash tool'un 10 dakikalık
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

## Neden Dev Sunucusu Slot Almaz

`cargo tauri dev` / `air` / `runserver` derleyip **saatlerce** koşar. Slot alsalardı slotu o süre
boyunca tutar ve guard'ın kendisi tıkanma sebebi olurdu. Onun yerine
`taskpolicy -b` ile arka plan QoS'una alınır: bloklamaz, CPU'yu ön plandaki derlemeye bırakır.
