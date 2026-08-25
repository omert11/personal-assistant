# Ağır Derlemeler — Sınırlı Slot (heavy)

Makinede (M1 Pro, 8 çekirdek / 16 GB) aynı anda birden fazla ağır derleme koşunca — özellikle
farklı projelerde paralel Claude oturumları varken — CPU ve bellek sıkışır, hepsi birden yavaşlar.
Çözüm: **ağır derlemeler proje ve dil fark etmeksizin ortak bir slot havuzundan geçer.**
Havuzun **taban genişliği** (`HEAVY_SLOTS`, varsayılan 2) garantilidir; üstündeki slotlar
çalışma anında **kazanılır** — taban doluyken **son** 30 saniyede CPU %90'ın altında kalmışsa
bir ek slot açılır. Tavan `HEAVY_MAX_SLOTS` (varsayılan 4); orada kuyruk serttir.

Pencere **makinenin** özelliğidir, bekleyenin değil: slotu tutanlar CPU örneklerini ortak bir
geçmişe yazar, yeni gelen iş bu geçmişe bakıp **anında** karar verir. Makine 10 dakikadır boşsa
yeni gelen 30 saniye beklemez — zaten ölçülmüş bir boşluğu yeniden ölçmenin anlamı yok.

## `heavy` Sarmalayıcı

```bash
heavy cargo build -p pingr      # bos slot varsa hemen koşar, yoksa sırada bekler
heavy go build ./...            # başka derleme koşuyorsa bekler
heavy --queue git commit -m x   # slot bekler ama tavan dolunca yine de koşar
heavy --low cargo tauri dev     # slot ALMAZ, arka plan QoS'unda koşar
heavy --status                  # dolu slotlar + kuyrukta bekleyenler (pid, cwd, süre)
HEAVY_SLOTS=2 heavy cargo test  # bu koşu için tabanı iki slota çık
HEAVY_MAX_SLOTS=1 heavy go test # bu koşu için ek slot açılmasını tamamen kapat
```

`--status` hem slotu tutanı hem sırada bekleyenleri listeler: her bekleyen kaç
saniyedir beklediğini, hangi modda (`slot` / `queue`) olduğunu, cwd'sini ve komutunu
yazar. Bekleyen kaydı slot alınır alınmaz düşer; öldürülmüş bir bekleyenin artığı
sonraki `--status` çağrısında temizlenir.

- Slot havuzu: `~/.cache/heavy-build.lock.<n>`, `/usr/bin/lockf` ile (`flock` macOS'ta yok).
  `lockf` tek dosya kilitler, bu yüzden N slot = N kilit dosyası, round-robin denenir.
- Taban slot sayısı `HEAVY_SLOTS` (varsayılan 2). Tek sıra istenirse `HEAVY_SLOTS=1`.
- **Paylaşılan CPU geçmişi**: `~/.cache/heavy-build.cpu`, satır başına `<epoch> <busy%>`.
  Slotu tutan her koşu arka planda `iostat` ile 2 sn'de bir örnek **ekler** (`>>`, satırlar
  kısa olduğu için kilit gerekmez; yinelenen saniye zararsız). Havuz doluysa tanım gereği en az
  bir tutan vardır — yani karar anında geçmiş de vardır. Sampler işi bitince ölür, dosya son
  200 satıra kırpılır.
- **Ek slot (yan yol)**: taban dolu bulan koşu geçmişe bakar ve şu üç karardan birini alır:
  - `clean` — pencere baştan sona kapalı, taze, boşluksuz ve her örnek `HEAVY_CPU_CEIL`
    (varsayılan 90) altında → genişlik **anında** bir artar, yeni kilit **beklemeden** denenir.
  - `busy` — pencerede tavanı aşan en az bir örnek var → büyüme yok. Örnek pencereden
    kayınca (30 sn) karar kendiliğinden `clean`'e döner.
  - `thin` — geçmiş yok / bayat / kısa / delikli → büyüme yok. Bekleyen kendi örneklerini
    aynı dosyaya yazar, pencere dolunca `clean` olur. **Ölçüm yokluğu "makine boş" kanıtı
    değildir**; `iostat` hiç yoksa büyüme hiç olmaz.
- **Kademelilik beklemede değil, `last_grant`'te**: ilk ek slot pencere temizse bedavadır;
  sonraki her slot bir öncekinden **30 sn duvar saati** sonra gelir. `HEAVY_MAX_SLOTS`'a
  ulaşınca büyüme durur, kuyruk sertleşir.
- Genişlik **koşu başınadır, paylaşılmaz**: 1 slotla başlayan bir bekleyen, başkasının açtığı
  3. slotu görmez; oraya girmek için kendisinin de oraya kadar büyümesi gerekir. Kilitler ortak
  olduğu için eşzamanlı iş sayısı yine `HEAVY_MAX_SLOTS`'u aşamaz.
- Ek slotta koşan iş loga `mode=slot-grown` olarak yazılır — `heavy --stats` mod dağılımında
  büyümenin ne kadar iş kurtardığı görünür.
- `heavy --status` tabandan tavana kadar tüm slotları listeler (`taban` / `ek` etiketiyle);
  aksi hâlde 3. slota büyümüş bir koşu hiçbir yerde görünmezdi.
- Makine-lokal ayar: `~/.config/heavy/config.sh` (`HEAVY_CONFIG` ile değiştirilir). Yalnız
  `HEAVY_SLOTS` / `HEAVY_MAX_SLOTS` / `HEAVY_GROW_WINDOW` / `HEAVY_CPU_CEIL` /
  `HEAVY_TIMEOUT` / `HEAVY_STATE_DIR` / `HEAVY_LOG` okunur (`HEAVY_NO_SAMPLER=1` sampler'ı
  kapatır, yalnız test için); plugin güncellemesi dosyayı ezmez,
  her çağrı için geçerlidir (Claude hook, solo, terminal, launchd). **Komut satırındaki env her
  zaman üstün gelir** — dosya yalnız boş bırakılanı doldurur. Dosya alt kabukta okunur: bozuk bir
  config (tanımsız değişken, `exit`) uyarı verip varsayılana düşer, derlemeyi sessizce atlamaz.
  Bu makinede dosya `HEAVY_SLOTS=1` + `HEAVY_MAX_SLOTS=4`: tek garanti slot, üstü CPU
  penceresiyle kazanılır.
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
- Her slotlu koşu `~/.cache/heavy-build.log` dosyasına tek satır yazar: mod, slot sayısı,
  kuyrukta bekleme, çalışma süresi, çıkış kodu, o anki load, cwd, komut. `HEAVY_LOG` ile yeri
  değişir, `HEAVY_LOG=off` kapatır. Dosya 600 izinli, 512 KB'ı aşınca son 2000 satıra düşer;
  komuttaki `*_KEY/TOKEN/SECRET/PASSWORD` değerleri `***` ile maskelenir (holder ve kuyruk
  dosyalarında da).
- `heavy --stats` bu logu özetler: kaç koşu, kaçı kuyrukta bekledi, toplam/ortalama bekleme,
  bekleme/çalışma oranı, ortalama load, en uzun bekleyen komut, mod dağılımı.
- Kaynak: `personal-assistant/scripts/heavy.sh`; oturum başında `~/.local/bin/heavy` symlink'i kurulur.

**Slot sayısını artırmanın bedeli**: iki Rust derlemesi çakışırsa (`jobs = 6` × 2 = 12 iş) 16 GB'da
swap başlar ve sıraya almanın kazancı geri verilir. Tabanı yükseltmek bu bedeli **koşulsuz**
öder; yan yol ise yalnız makine boş göründüğünde öder — tabanın 1'de tutulup tavanın 4'e
açılmasının sebebi budur.

**Yan yolun bilinen kör noktası — CPU bellek darboğazını görmez.** Kapı 25 Ağustos 2026'da
bilinçli olarak CPU-only seçildi, ama ölçüm şunu gösteriyor: tek bir `cargo tauri build`
koşarken CPU idle %55-70, `kern.memorystatus_vm_pressure_level` = 2 (warn), swap 9531/10240 MB
dolu. O anda CPU kapısı **ek slot açar** ve ikinci derleme 700 MB boş swap'e girer. Daha eski
bir ölçüm de aynı yöne bakıyordu: load 18.47 iken CPU %46 idle — kuyruğu şişiren I/O
beklemesiydi. 16 GB'da asıl tavan bellektir. Ayrıca açılan slot geri alınamaz (koşan derleme
durdurulmaz), yani yanlış açılan bir slot o iş bitene kadar taşınır.
İzleme: `heavy --stats` mod dağılımında `slot-grown` payı ile `sysctl -n vm.swapusage`.
Swap büyümesi `slot-grown` koşularıyla birlikte artıyorsa kapıya bellek koşulu eklenir
(`kern.memorystatus_vm_pressure_level = 1` şartı) veya `HEAVY_MAX_SLOTS` düşürülür.

## Katman 1 — Claude PreToolUse Hook (otomatik)

`scripts/heavy-guard.sh` her Bash çağrısını süzer, `updatedInput` ile komutu yeniden yazar:

| Komut sınıfı | Ne olur |
|---|---|
| `cargo build/test/check/clippy/bench/doc/install`, `cargo tauri build`, `go build/test/vet/install/generate`, `golangci-lint run`, `npm\|pnpm\|yarn\|bun run build\|test`, `pytest`, `python -m pytest`, `manage.py test`, `next\|vite\|tsc\|turbo\|webpack\|esbuild build`, `xcodebuild`, `gradle`, `cmake --build`, `docker build`, `maturin build` | `heavy $SHELL -c '<komut>'` + **run_in_background: true** |
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

Test koşucuları ve linter'lar da ağır sınıftadır — derleyici kadar CPU yerler. `pytest` ayrı bir
desende tutulur (`PYTEST_RE`): `cargo build` gibi iki kelimelik adların aksine tek kelime argüman
olarak da geçer (`grep pytest`, `which pytest`), bu yüzden yalnız komut pozisyonunda —isteğe bağlı
`timeout N` önekiyle— sayılır.

Sarmalayıcı kabuk **`$SHELL`**'dir (bu makinede zsh), sabit `bash` değil. macOS'un `/bin/bash`'i
3.2.57'dir ve `$(cat <<'EOF' … EOF)` içinde apostrof geçen bir heredoc'u parse **edemez** —
yani tam olarak conventional commit mesajı kalıbını. `bash -c` ile sarmalamak komutu sessizce
başka bir dile taşır ve `git commit` sözdizimi hatasıyla düşer. Egzotik kabuklarda
(fish, nushell — `-c '<komut>'` semantiği farklı) `/bin/bash`'e düşülür.

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
