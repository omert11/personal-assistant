# Ağır Derlemeler — Sınırlı Slot (heavy)

Makinede (M1 Pro, 8 çekirdek / 16 GB) aynı anda birden fazla ağır derleme koşunca — özellikle
farklı projelerde paralel Claude oturumları varken — CPU ve bellek sıkışır, hepsi birden yavaşlar.
Çözüm: **ağır derlemeler proje ve dil fark etmeksizin ortak bir slot havuzundan geçer.**
Varsayılan **2 slot**: iki ağır derleme paralel koşar, üçüncüsü sırada bekler.

## `heavy` Sarmalayıcı

```bash
heavy cargo build -p pingr      # bos slot varsa hemen koşar, yoksa sırada bekler
heavy go build ./...            # başka derleme koşuyorsa bekler
heavy --queue git commit -m x   # slot bekler ama tavan dolunca yine de koşar
heavy --low cargo tauri dev     # slot ALMAZ, arka plan QoS'unda koşar
heavy --status                  # dolu slotlar + kuyrukta bekleyenler (pid, cwd, süre)
HEAVY_SLOTS=2 heavy cargo test  # bu koşu için iki slota çık
```

`--status` hem slotu tutanı hem sırada bekleyenleri listeler: her bekleyen kaç
saniyedir beklediğini, hangi modda (`slot` / `queue`) olduğunu, cwd'sini ve komutunu
yazar. Bekleyen kaydı slot alınır alınmaz düşer; öldürülmüş bir bekleyenin artığı
sonraki `--status` çağrısında temizlenir.

- Slot havuzu: `~/.cache/heavy-build.lock.<n>`, `/usr/bin/lockf` ile (`flock` macOS'ta yok).
  `lockf` tek dosya kilitler, bu yüzden N slot = N kilit dosyası, round-robin denenir.
- Slot sayısı `HEAVY_SLOTS` (varsayılan 2). Tek sıra istenirse `HEAVY_SLOTS=1`.
- Makine-lokal ayar: `~/.config/heavy/config.sh` (`HEAVY_CONFIG` ile değiştirilir). Yalnız
  `HEAVY_SLOTS` / `HEAVY_TIMEOUT` / `HEAVY_STATE_DIR` okunur; plugin güncellemesi dosyayı ezmez,
  her çağrı için geçerlidir (Claude hook, solo, terminal, launchd). **Komut satırındaki env her
  zaman üstün gelir** — dosya yalnız boş bırakılanı doldurur. Dosya alt kabukta okunur: bozuk bir
  config (tanımsız değişken, `exit`) uyarı verip varsayılana düşer, derlemeyi sessizce atlamaz.
  Bu makinede dosya `HEAVY_SLOTS=1` — 16 GB'da iki paralel Rust derlemesi swap'e giriyor.
- Tutan süreç `~/.cache/heavy-build.current.<n>` dosyasına yazılır — bekleyen neyi beklediğini görür.
- Bekleme tavanı `HEAVY_TIMEOUT` (varsayılan 1200 s). Tavan aşılırsa komut **çalıştırılmaz**,
  çıkış kodu 75 olur — takılan bir derleme herkesi süresiz bloklamasın.
- Komutun kendisi 75 ile çıkarsa bu "slot dolu" ile karışmaz: iç sarmalayıcı 175'e çevirir,
  dış taraf geri 75 yapar. Aksi hâlde komut ikinci kez çalıştırılırdı.
- `--queue`: slot bekler ama tavan dolunca komutu **slotsuz çalıştırır** (rc=75 ile atlamaz).
  Derlemeyle CPU yarışmaması gereken ama hiçbir koşulda bloke olmaması gereken işler için.
- Slot tutan bir komutun içinden `heavy` çağrılırsa (ör. `heavy bash -c '... heavy go test ...'`)
  iç çağrı **slot beklemez, mevcut slotu kullanır** (`HEAVY_SLOT_HELD`). Aksi hâlde dış heavy
  kendi iç heavy'sinin beklediği slotu tutar — tek slotlu makinede kesin kilitlenme.
- Kaynak: `personal-assistant/scripts/heavy.sh`; oturum başında `~/.local/bin/heavy` symlink'i kurulur.

**Slot sayısını artırmanın bedeli**: iki Rust derlemesi çakışırsa (`jobs = 6` × 2 = 12 iş) 16 GB'da
swap başlar ve sıraya almanın kazancı geri verilir. 2'nin üstüne çıkmadan önce ölçülmeli.

## Katman 1 — Claude PreToolUse Hook (otomatik)

`scripts/heavy-guard.sh` her Bash çağrısını süzer, `updatedInput` ile komutu yeniden yazar:

| Komut sınıfı | Ne olur |
|---|---|
| `cargo build/test/check/clippy/bench/doc/install`, `cargo tauri build`, `go build/test/vet/install/generate`, `npm\|pnpm\|yarn\|bun run build`, `next\|vite\|tsc\|turbo\|webpack\|esbuild build`, `xcodebuild`, `gradle`, `cmake --build`, `docker build`, `maturin build` | `heavy bash -c '<komut>'` + **run_in_background: true** |
| `cargo run/watch`, `cargo tauri dev`, `go run`, `air`, `npm/pnpm/yarn/bun run dev\|start\|watch`, `next dev`, `vite`, `nodemon`, `manage.py runserver` | `heavy --low bash -c '<komut>'` (slot almaz) |
| `git commit`, `git push` | `heavy --queue bash -c '<komut>'` (slot bekler, tavan dolunca yine koşar) |
| `cargo tree/metadata/fmt`, `go env/list/fmt`, diğer her şey | dokunulmaz |

Sınıflandırma **komut iskeleti** üzerinde yapılır: heredoc gövdeleri, tırnaklı stringler ve
`#` yorumları maskelenir, `bash -c '<komut>'` içeriği ayrı aday olarak eklenir. Böylece
`git commit -m "perf: cargo build faster"` bir commit'tir, derleme değil; kanıt dosyasına
test çıktısı yazan heredoc da derleme sayılmaz. Maskeleme soldan sağa tek geçiştir —
`"worktree'ye ait"` gibi metindeki apostrof sonraki tırnak aralıklarını kaydırmaz.

`git commit` / `git push` neden kuyruğa girer: **guard yalnız Claude'un yazdığı komutu görür,
o komutun tetiklediği git hook'larını değil.** pre-commit black/eslint/djlint koşturur,
lefthook pre-push doğrudan `cargo test` başlatır — bunlar slot havuzunun tamamen dışında
kalır, `--status` boş görünürken makine rustc'lerle dolar. Çare: hook'u tetikleyen git
fiili slotu onlar adına alır. `--queue` olduğu için en fazla `HEAVY_TIMEOUT` kadar bekler,
sonra slotsuz koşar — commit/push hiçbir zaman bloke olmaz. Kuyruğa girebilen her sınıfa
`timeout: 600000` verilir; Bash tool'un 120 s varsayılanı bekleme tavanından kısadır ve
komutu daha sırada beklerken öldürürdü. Diğer git fiilleri (status/diff/log) anlıktır,
dokunulmaz.

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
