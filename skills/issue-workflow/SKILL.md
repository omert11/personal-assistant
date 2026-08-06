---
name: issue-workflow
description: Issue/ticket/doc/gorsel kaynagini HTML analiz akisiyla cozer, kanitlar.
when_to_use: Trigger — "su ticket'i coz", "issue-workflow ile bak", "bu hatayi worktree'de coz", "ticket analiz et ve duzelt", "su dokumandaki sorunu hallet", "yonetici modunda", "fazlandirarak yap", "/issue-workflow <ref|metin>". Bir issue/ticket/dokuman/gorsel/mesaj kaynagi verilip uctan uca (kaynak → HTML analiz → plan → cozum → kanit → commit) cozulmesi istendiginde. Orta/buyuk islerde yonetici modu: tum is tek Workflow'da fazlanir, kontrol sonda tek seferde. Tek seferlik kucuk duzeltmeler icin gerekmez.
argument-hint: <ticket-ref | serbest-metin | dosya-yolu>
disable-model-invocation: false
effort: max
allowed-tools: Bash, BashOutput, KillShell, Read, Write, Edit, Grep, Glob, AskUserQuestion, Monitor, TaskList, TaskGet, TaskStop, TaskCreate, TaskUpdate, WebFetch, Workflow, EnterWorktree, ExitWorktree, EnterPlanMode, ExitPlanMode, Skill
---

# Issue Workflow — Kaynak → HTML Analiz → Plan → Cozum → Kanit → Commit

Verilen bir **kaynagi** (Plane issue, serbest metin, dokuman, gorsel, mail, log) uctan uca cozer.
Omurga **tek buyuyen lokal HTML analiz sayfasidir**: analiz uc grup halinde ayni dosyaya yazilir,
her grupta kullaniciyla sohbet edilir. Cozum izole worktree'de uygulanir, kanitlarla teyit edilir,
teslimat `commit` skill'e devredilir.

> **Bu skill isleri SIRALAR — agir mantigi ayri skill'lere delege eder.** Worktree → `worktree`,
> teslimat + code-review → `commit`, log → `diji-logs`, Plane → `plane-cli`, analiz sayfasi →
> `user-render`.

## Temel Ilke — Kontrol Sonda, Tek Seferde

Is tamamlanana kadar **ara kontrol yok**: ara commit, ara build, ara review, asamali teslim
YAPILMAZ. Surec icinde kirik noktalar normaldir. Tek PR acilir; dogrulama, review ve kanit **isin
sonunda bir kez** kosar. Bu ilke tum akisi belirler — kod butunlugu ara dogrulamayla degil,
**sozlesme faziyla** (yonetici modu) saglanir.

## Durus — Agent Uzmandir

Kullanici **istek** bildirir; en dogru yolu agent belirler. Istegin arkasindaki ihtiyaci coz.

- **Kolay olani degil DOGRU olani sec** — ilk calisan cozumde durma, daha zarif/basit yol ara
- **Global standarda bak** — sektorde/framework'te yerlesik pattern varsa onu tercih et
- **Durust ol** — yapisal imkansizligi "olur" deme, ek kazanimi gizleme; ikisi de sayfaya islenir

> ## ⚠ Sub-agent YASAGI — Adim 2 ve Adim 4
> **Kaynak toplama (Adim 2) ve kok-neden analizi (Adim 4) ASLA delege edilmez.** Sub-agent izole
> context'te calisir, ana baglamdan kopar, eksik analiz uretir. Ikisi de **ana ajanda, `effort: max`**
> ile yapilir. (Skill delegasyonlari — `obsidian-search`/`diji-logs`/`worktree`/`commit`/`plane-cli` —
> sub-agent degildir, ana agent context'inde calisirlar.)

## Model ve Effort — Her Delege Cagrisinda Acik

`token-efficiency` kurali: `Workflow` script'lerindeki **her `agent()` cagrisina acik `model` VE
`effort` yazilir** — bosa birakilan effort oturumunkini devralir, bu skill `effort: max` ile kostugu
icin mekanik bir ajan bile `max` dusunur (yavas + pahali).

| Is | model | effort |
|---|---|---|
| Sozlesme faziyla imza/tip/sema tasarimi | `opus` | `high` |
| Kod yazma, refactor, test yazimi, fix | `opus` | `medium` |
| Mekanik uygulama (rename, tasima, sablon doldurma) | `sonnet` | `low` |
| Salt-okunur arama / envanter / log tarama | `sonnet` | `low` |

⛔ **Fable Model Baraji**: fable oturumunda hicbir `agent()` fable ile kosmaz — ust sinir `opus`;
hazir/named workflow (`Workflow({name: ...})`) dogrudan launch edilmez. `haiku` kullanilmaz.

## Analiz Sayfasi (Adim 3, 4, 8)

Sayfanin **nasil** yazilacagi `user-render` skill'inde tanimlidir — ilk yazimda o skill'i yukle.
Konu slug'i = `<isim>` (Adim 5). Bu akisa ozel iki kural:

- **Bolum numaralari (B1..B11) korunur** — her grupta yeni bolumler ayni dosyaya EKLENIR
- **Sohbet kapisi** (Adim 3, 4, 8 sonunda): sayfa yazildiktan sonra `AskUserQuestion` (header:
  "Akis") — `["Akisa devam et", "Duzenleme/istek var"]`; Adim 8'de `["Commit skill calistir",
  "Duzenleme/istek var", "Iptal"]`. "Duzenleme" → istegi al, sayfayi guncelle, TEKRAR sor;
  kullanici devam diyene kadar adimda kalinir

---

## Adim 1 — CLAUDE.local.md "## Issue Workflow" alanini oku (ILK IS)

```bash
grep -n "## Issue Workflow" CLAUDE.local.md 2>/dev/null
```

Varsa tamamini oku ve uygula — bagimlilik kurulumu, uygulama baslatma komutu, test komutlari, port
stratejisi, proje-ozel akis notlari oradadir. Yoksa zorlama; is sirasinda proje-ozel bir ihtiyac
dogarsa bolumu olustur (sablon Ek'te) ki sonraki calismalar okusun.

---

## Adim 2 — Kaynak toplama (ATLANAMAZ, ANA AJAN)

Her kaynagi **tek tek, tam detayli** incele — gorseller dahil. Ozetle gecme.

| Kaynak | Nasil al |
|---|---|
| **Plane issue** (`PROJ-123`) | `plane-cli` skill → `issue get-id` + `issue get` + `comment list` (tum yazismalar) + ekler; ekli gorseli indir ve oku |
| **Serbest metin / mesaj** | Dogrudan oku, talebi madde madde cikar |
| **Gorsel** | `Read` ile gor — hata metni, kod, URL cikar. TR hata mesajiysa orijinal msgid'i `grep ... locale/*/LC_MESSAGES/*.po` ile bul |
| **Dokuman** (PDF/Word/HTML) | `markitdown <dosya> > /tmp/src.md` sonra oku; URL ise `WebFetch` |
| **Log / hata ciktisi** | VictoriaLogs'lu diji projesiyse `diji-logs` skill; kapsamli tarama `log-triage`; degilse `Grep` |

> Obsidian vault tanimliysa `obsidian-search` ile bak — onceki oturum bu sorunu cozmus olabilir.

Cikti: anahtar veriler (ref, hata kodu, kullanici, tarih, modul/dosya/endpoint) context'te hazir.

---

## Adim 3 — Analiz Sayfasi Grup 1 (B1–B3) + sohbet kapisi

`user-render` skill'ini yukle, ilk uc bolumu yaz (`~/.pa-render/active/<isim>/index.html`):

- **B1 — Suanki Durum**: sistemin bugunku davranisi — akis semasi, modul haritasi, hata gorseli
- **B2 — Ne Isteniyor**: talep, somut ve madde madde; once/sonra karsilastirmasi uygunsa
- **B3 — Neden Isteniyor**: ihtiyacin koku — is degeri, etkilenen kullanici/akis, aciliyet

Sonra **sohbet kapisi**. Kaynak anlayisindaki yanlislik burada duzelir; sonraki adimlar bunun
uzerine kurulur.

---

## Adim 4 — Analiz Sayfasi Grup 2 (B4–B7): durum + yol haritasi (ULTRATHINK, ANA AJAN)

> **Derin dusun** — `effort: max`. Yuzeysel ilk hipotezde durma; kodu/logu gerektigi kadar incele
> (`Grep`/`Glob`/`Read`/`Bash`). Kok nedeni bul, semptomu degil. **Sub-agent kullanma.**

Ayni dosyaya dort bolum EKLE (`Edit`):

- **B4 — Ne Hazir / Ne Yapilacak / Nasil Yapilacak**: yol haritasi semasi ile
- **B5 — Oneriler / Iyilestirmeler**: talebin otesinde gorulen firsatlar
- **B6 — Acik Konular**: kararlastirilmasi gereken her sey, secenekleriyle
- **B7 — Riskler / Durust Avantaj / Durust Dezavantaj**: risk matrisi, suslenmemis arti-eksi

**Acik konularin TAMAMI burada kapatilir**: her B6 maddesi icin `AskUserQuestion` ile karar al
(onerilen isaretli), karari sayfaya isle. Sonra **sohbet kapisi**.

---

## Adim 4.5 — Uygulama modu kapisi

| Durum | Mod | Ne degisir |
|---|---|---|
| Tek is paketi, dar kapsam, tek dosya kumesi | **Tek akis** (varsayilan) | Hicbir sey — Adim 7 aynen |
| 2+ ayrik gorev veya sirali bagimlilik iceren orta/buyuk is | **Yonetici modu** | Adim 7 yerine **7Y** ([references/yonetici-modu.md](references/yonetici-modu.md)); plan fazlanir |

**Kullanici soylediyse dogrudan acilir** (sorulmaz): "yonetici modunda", "fazlandirarak yap",
"is paketlerine bol", "workflow ile yurut".

**Aksi halde `AskUserQuestion`** (header: "Mod", `["Yonetici modu", "Tek akis"]`) — su
sinyallerden **en az ikisi** varsa sor; hicbiri yoksa sormadan tek akisla devam et:

- B4'te birbirinden bagimsiz **2+ gorev** (ayrik dosya kumeleri)
- **Sirali baglilik**: bir isin ciktisi digerinin girdisi
- Tek elden tek oturumda bitmeyecek buyukluk (genis refactor, coklu modul, migration + UI + API)

**Yonetici modu ozeti**: tum is **tek `Workflow` script'inde** fazlanarak yazilir (ilk faz
sozlesme), agent'lar yalniz kod yazar; dogrulama + kanit + review **sonda tek seferde**. Diger
adimlar (1-6, 8, 8.5, 9, 10) degismez.

> Delegasyon yalniz **uygulamayi** dagitir; Adim 2 ve Adim 4 her modda ana ajanda kalir.

---

## Adim 5 — Worktree ac + Plan modu

Kaynaktan **kebab-case** isim turet: Plane issue → `fix-<issue-ident>`, bug → `fix-<konu>`,
feature → `feat-<konu>`. `worktree` skill'inin `new <isim>` akisini kullan (veya
`EnterWorktree({ name })`). Session cwd worktree'ye gecer; kanit klasoru
`~/.pa-render/active/<isim>/` — sayfayla ayni yer.

> **`SESSION_NAME` = bu isim.** Adim 7'de eklenen debug loglari `[SESSION_NAME]` ile etiketlenir,
> Adim 8.5 ayni etiketle temizler. Deger context'te sabit tutulur.

Sonra `EnterPlanMode()` ile tam plani yaz:

- Yapilacak degisiklikler — hangi dosyada ne
- Kapatilan acik konularin kararlari
- Yan etki / risk ve nasil dogrulanacagi
- **Debug loglama**: dilin logger'i varsa `[SESSION_NAME]` etiketli loglar eklenecegini belirt
- **Yonetici modundaysa faz tablosu**: sozlesme fazi + sirali fazlar, her fazin gorevleri ve
  **gorev basina yazilabilir dosya yollari** (ayni dosyaya yazan gorevler ayni fazda olamaz)

`ExitPlanMode()` onayi **tek onay noktasidir** — ayrica "onayliyor musun?" diye SORMA. Onay
alindiktan sonra is, sert durak cikmadikca sonuna kadar yurutulur.

---

## Adim 6 — Plane issue'yu ISLEME AL (kaynak Plane issue ise; OTOMATIK)

Plan onaylandi = is basliyor. Kaynak Plane issue degilse veya proje tanimli degilse atlanir.
Onay sorma, uygula ve tek satir bildir. CLI sozdizimi `plane-cli` skill'inden (`--json`):

1. `issue get` — mevcut assignee / `start_date` / state group
2. Yalnizca `backlog`/`unstarted` ise `started`'a cek — zaten started/completed/cancelled ise DOKUNMA
3. Assignee bossa self ata (`issue assignee --add`, incremental; REPLACE yapan `update --assignees` KULLANMA)
4. `start_date` bossa bugunu ata

> **Idempotent** — dolu alan bozulmaz. Label/priority/target-date `commit` skill'in isidir.

---

## Adim 7 — Uygula + Test + Kanit

> **Yonetici modunda** bu adim yerine `references/yonetici-modu.md` (**7Y**) kosar: tum is tek
> Workflow'da fazlanir, dogrulama + fix ana agentta, kanit asagidaki 7a-7d ile **isin sonunda**
> uretilir.

Plani uygula (`coding` kurallari: hata wrap, TODO yorumu, workaround yok).

> **`[SESSION_NAME]` loglama (dil izin veriyorsa):** kritik akis noktalarina `[SESSION_NAME]`
> prefix'li detayli log ekle (orn `logger.debug("[fix-proj-123] payment intent %s created", pid)`).
> Amac teshis: test sirasinda grep'lenir, Adim 8.5'te temizlenir. Logger yoksa zorlama.

```bash
EVID=~/.pa-render/active/<isim>       # sayfayla ayni klasor → goreli <img src="..."> calisir
mkdir -p "$EVID"
```

### 7a. Test ortamini worktree'de hazirla
Worktree izole kopyadir — uygulamayi burada kur, ana checkout'a dokunma. Komutlar Adim 1'den;
yoksa proje tipinden cikar (Python `uv venv` + requirements, Node `npm install`, Go `go build ./...`).

### 7b. Unique port ile ARKA PLANDA calistir
```bash
PORT=$(python3 -c "import socket;s=socket.socket();s.bind(('',0));print(s.getsockname()[1]);s.close()")
echo "$PORT" > "$EVID/.port"
# run_in_background: true — orn:
#   Django: .venv/bin/python manage.py runserver 127.0.0.1:$PORT 2>&1 | tee $EVID/server.log
#   Node:   PORT=$PORT npm run dev 2>&1 | tee $EVID/server.log
```
Bound port'u bekle (`curl --retry`), hazir olunca testlere gec.

### 7c. Testler + kanit dosyalari
| Sorun tipi | Kanit araci | Cikti |
|---|---|---|
| **Gorsel / UI / akis** | `playwright-cli` skill (`PORT`'a baglan) | `$EVID/screenshot-*.png` (before/after) |
| API / backend endpoint | `curl` (`localhost:$PORT`) | `$EVID/api-before.json`, `api-after.json` |
| Mantik / fonksiyon | test (`pytest` / `npm test`) | `$EVID/test-output.txt` |
| Veri / DB / log | shell sorgu | `$EVID/query-result.txt` |
| Her durum | before/after diff | `$EVID/diff.txt` |

> **Gorsel degisiklikte GORSEL KANIT ZORUNLU** — screenshot yoksa gorsel cozum kanitlanmis sayilmaz.
> Teshis icin `grep "\[SESSION_NAME\]" $EVID/server.log` ile eklenen loglari kullan.

### 7d. Arka plandaki uygulamayi DURDUR (ZORUNLU)
`KillShell` (gerekirse `kill $(lsof -ti tcp:$PORT)`), playwright acikca `playwright-cli close`.
Hata/iptal durumunda da yapilir — orphan process/port birakilmaz.

> Kanit dosyalari canli credential icerebilir → her zaman `$EVID` altinda, **repo disi**. Sayfaya
> gomulen gorselde credential kontrolu yap.

---

## Adim 8 — Analiz Sayfasi Grup 3 (B8–B11) + sohbet kapisi

Ayni dosyaya son dort bolumu EKLE:

- **B8 — Acik Konular (kapanis)**: B6'daki her maddenin karari + uygulanma durumu; yeni doganlar
- **B9 — Kanitlar**: `$EVID/` ciktilari; screenshot'lar goreli yolla (`<img src="screenshot-after.png">`),
  her kanitin NEYI ispatladigi tek cumleyle
- **B10 — Ek Kazanclar**: yan iyilestirmeler (temizlenen kod, kapatilan baska bug, performans)
- **B11 — Son Durum / Yeni Akis**: cozum sonrasi davranis, once/sonra karsilastirmasi

Sonra **sohbet kapisi** — `["Commit skill calistir", "Duzenleme/istek var", "Iptal"]`.
"Duzenleme" kod degisikligi gerektiriyorsa Adim 7'ye don (kanit yenile). "Iptal" →
`ExitWorktree({ action: "keep" })` + durum raporu.

---

## Adim 8.5 — `[SESSION_NAME]` log temizligi (BLOKLAYICI)

```bash
grep -rn "\[<SESSION_NAME>\]" .
```

- **Gecici debug** (akis izleme, degisken dump) → satiri **komple sil**
- **Kalici faydali log** (prod'da anlamli) → kalir, ama `[SESSION_NAME]` etiketi **cikarilir**

`grep` **bos donene kadar** bu adimda kalinir; etiket kalirsa Adim 9'a gecilmez. Temizlik sonrasi
kritik akisi bir kez daha dogrula (log silerken kod bozulmus olabilir). Log eklenmemisse atlanir.

---

## Adim 9 — Commit skill (tek teslimat, tek PR)

`commit` skill'e delege et — **code-review bu akisin tek review noktasidir** ve orada kosar
(buyuk diff'te dosya kumesine gore paralel `claude -p` oturumlarina bolunur; bulgu duzeltmesi
`Workflow` ile dagitilabilir). Teslimat tek commit + tek PR. Plane kapama da `commit` skill'in isi.

> Yonetici modunda **ara commit atilmadigi** icin buradaki diff tum isi kapsar — review'in
> bolunmesi beklenen normaldir.

---

## Akis Ozeti

```
1.  CLAUDE.local.md "## Issue Workflow" oku      (proje-ozel komut/port/test notu)
2.  Kaynak toplama — TAM detay, ANA AJAN         (plane-cli / Read / markitdown / WebFetch / diji-logs)
3.  HTML B1-B3 (user-render)                     → SOHBET KAPISI
4.  HTML B4-B7 — ULTRATHINK, ANA AJAN            (acik konular KAPATILIR) → SOHBET KAPISI
4.5 Mod kapisi                                   (tek akis / yonetici modu)
5.  Worktree + EnterPlanMode                     (SESSION_NAME; yonetici modunda faz tablosu) → ExitPlanMode
6.  Plane issue ise ISLEME AL — OTOMATIK         (started + self + start_date; idempotent)
7.  Uygula → test ortami → unique port → kanit → DURDUR
    [yonetici modu] 7Y: TEK Workflow (sozlesme fazi + fazlar) → ana agent dogrular → fix workflow → kanit
8.  HTML B8-B11                                  → SOHBET KAPISI
8.5 [SESSION_NAME] log temizligi — BLOKLAYICI    (grep bos donene kadar)
9.  commit skill                                 (code-review + tek PR + Plane kapama orada)
10. Arsivle                                      (mv ~/.pa-render/active/<isim> ~/.pa-render/archive/)
```

## Entegrasyon Notlari

- **Kontrol sonda**: ara commit / ara build / ara review / asamali teslim YOK; dogrulama, review,
  kanit isin sonunda bir kez
- **Delegasyon**: worktree → `worktree`, teslimat + review → `commit`, log → `diji-logs`
  (kapsamli tarama `log-triage`), Plane → `plane-cli`, analiz sayfasi → `user-render`
- **Sub-agent siniri**: Adim 2 ve Adim 4 asla delege edilmez; Obsidian arama/yazma da ana ajanda
- **Sohbet kapilari**: Adim 3, 4, 8 — kullanici acik onay verene kadar adimda kalinir
  (`ask-first`: soru her zaman `AskUserQuestion` ile)
- **Plan onayi**: tek onay noktasi `ExitPlanMode`; acik konular ondan ONCE (B6) kapatilir
- **Yonetici modu** ([references/yonetici-modu.md](references/yonetici-modu.md)): tum is tek
  `Workflow`'da fazlanir (ilk faz **sozlesme**: imza/tip/sema — ara build ihtiyacini bu ortadan
  kaldirir), agent'lar yalniz kod yazar, dogrulama/fix/kanit ana agentta ve sonda; ana agent
  **watchdog dongusu** ile is bitene kadar uyanik tutulur
- **Kanit izolasyonu**: her zaman `~/.pa-render/active/<isim>/` — repo'ya kanit/credential sizmaz

## Ek — `CLAUDE.local.md` "## Issue Workflow" Sablonu

```markdown
## Issue Workflow

- **Bagimlilik kurulum**: <orn `uv venv && source .venv/bin/activate && uv pip install -r requirements.txt`>
- **Baslatma komutu**: <orn `.venv/bin/python manage.py runserver 127.0.0.1:$PORT`>
- **Test komutu**: <orn `pytest`, `npm test`, `playwright test`>
- **Build/lint komutu**: <orn `cargo build`, `npm run lint`, `mypy .`>
- **Port**: unique (otomatik) | sabit gerekiyorsa: <port>
- **Ek servisler**: <redis/postgres gerekli mi, nasil ayaga kalkar>
- **Akis notlari**: <bu projede dikkat edilecekler>
```
