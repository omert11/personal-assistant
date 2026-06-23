---
name: issue-workflow
description: Issue/ticket/doc/gorsel kaynagini analiz eder, worktree acar, cozer, kanit toplar.
when_to_use: Trigger — "su ticket'i coz", "issue-workflow ile bak", "bu hatayi worktree'de coz", "ticket analiz et ve duzelt", "su dokumandaki sorunu hallet", "/issue-workflow <ref|metin>". Bir issue/ticket/dokuman/gorsel/mesaj kaynagi verilip uctan uca (analiz → izole worktree → cozum → kanit → onay) cozulmesi istendiginde. Tek seferlik kucuk duzeltmeler icin gerekmez; kok-neden analizi + izolasyon + kanit gerektiren islerde.
argument-hint: <ticket-ref | serbest-metin | dosya-yolu>
disable-model-invocation: false
effort: max
allowed-tools: Bash, BashOutput, KillShell, Read, Write, Edit, Grep, Glob, AskUserQuestion, Task, WebFetch, EnterWorktree, ExitWorktree, EnterPlanMode, ExitPlanMode, Skill
---

# Issue Workflow — Analiz → Izole Worktree → Coz → Kanit → Onay

Verilen bir **kaynagi** (Plane issue, serbest metin, dokuman, gorsel, mail, log)
uctan uca cozer: tam baglam cikarir, izole worktree'de calisir, kok-neden analizi yapar,
cozum **kesinse** uygular / **belirsizse** durup sorar, calismayi kanitlarla teyit eder,
kanit klasorunu acip onay bekler.

> **Bu skill yalniz isleri SIRALAR — agir mantigi (worktree, commit) ayri skill'lere delege eder.**
> Worktree → `worktree` skill. Teslimat → `commit` skill. DRY.

> ## ⚠ Sub-agent YASAGI — Adim 0 ve Adim 2
> **Kaynak analizi (Adim 0) ve kok-neden analizi (Adim 2) ASLA sub-agent'a yaptirilmaz.**
> Bulgular ve analiz bu isin kritik cekirdegidir; sub-agent izole context'te calisir ve
> ana baglamdan kopar — yanlis/eksik analiz uretir. Bu iki adimi **her zaman ana ajan kendi
> context'inde, `effort: max` ile** yapar. `Task` tool bu adimlarda kullanilmaz.
> (Tek istisna: Adim 0'da `obsidian-searcher` *on aramasi* — analiz yapmaz, sadece gecmis notu
> context'e GETIRIR; ve `diji-log-search`/`worktree`/`commit` gibi **skill delegasyonlari** —
> bunlar sub-agent degil, ayri skill cagrilaridir.)

---

## Adim 0a — Skille ozel local alani oku (ILK IS)

Ise baslamadan once `CLAUDE.local.md`'de **"## Issue Workflow"** bolumu var mi bak:

```bash
grep -n "## Issue Workflow" CLAUDE.local.md 2>/dev/null
```

Varsa **tamamini oku ve uygula** — bu projedeki akisa ozel talimatlar burada tanimlidir:
- **Uygulama baslatma komutu** (orn `uv run manage.py runserver`, `npm run dev`, `go run .`)
- **Test komutlari** (orn `pytest`, `npm test`, ozel e2e komutu)
- **Port stratejisi** / ortam degiskenleri (varsayilan port, baska gerekli servisler)
- **Bagimlilik kurulum** adimlari (worktree'de calistirilacak)
- **Kullanici-ozel akis notlari** (bu projede dikkat edilecekler)

> Bu bolum **yoksa** zorlama — genel akisla devam et. Kullanici akisa ozel bir sey eklemek isterse
> (veya is sirasinda boyle bir ihtiyac dogarsa), `CLAUDE.local.md`'ye **"## Issue Workflow"** bolumu
> ekle/guncelle ki sonraki calismalar bunu otomatik okusun. Sablon Ek bolumde.

---

## Adim 0b — Kaynagi tam analiz et ve contexte al (ATLANAMAZ, ANA AJAN)

Kullanicinin verdigi her kaynagi **tek tek, tam** incele. Hicbirini atlama, ozetle gecme.
**Bu adim sub-agent'a verilmez** — kaynagi ana ajan kendi context'inde okur (yukaridaki sub-agent yasagi).

| Kaynak tipi | Nasil al |
|---|---|
| **Plane issue** (`PROJ-123`, `61618`) | `plane-cli` skill → `issue get-id PROJ-123` (UUID coz) + `issue get` + `comment list` (tum yazismalar) + ekler. Ekli gorsel/dosya varsa indir ve oku |
| **Serbest metin / mesaj** | Dogrudan oku, talebi/sikayeti madde madde cikar |
| **Gorsel** (ekran goruntusu, hata diyalogu) | `Read` ile gor — hata metni, kod, ekran durumu, URL'leri cikar. TR hata mesaji ise orijinal msgid'i `grep ... locale/*/LC_MESSAGES/*.po` ile bul |
| **Dokuman** (PDF/Word/HTML/dosya) | `markitdown <dosya> > /tmp/src.md` ile markdown'a cevir, sonra oku. URL ise `WebFetch` |
| **Log / hata ciktisi** | Diji b2c projesiyse `diji-log-search` skill'e delege et (basket lifecycle); degilse Grep ile ilgili log dosyalarini tara |

**Cikti — kisa bir baglam ozeti** (kullaniciya goster):
- Ne isteniyor / ne bozuk (somut, tek cumle)
- Hangi modul/dosya/endpoint ilgili gorunuyor
- Verilen tum kaynaklarda gecen anahtar veriler (ref, hata kodu, kullanici, tarih)

> Obsidian vault tanimliysa baslamadan once `obsidian-searcher` agent'ini `run_in_background: true`
> ile cagir (QUERY: sorunun ozeti) — onceki oturum bu sorunu cozmus olabilir.

---

## Adim 1 — Worktree ac ve o ortama gec (worktree skill'e delege)

Issue'dan **anlamli, kebab-case** bir isim turet:
- Plane issue → `fix-<issue-ident>` (orn `fix-proj-123`)
- Bug → `fix-<kisa-konu>` (orn `fix-payment-timeout`)
- Feature → `feat-<kisa-konu>`

`worktree` skill'inin `new <isim>` akisini kullan (icinde `EnterWorktree({ name })` var):

```
Skill(worktree, "new <isim>")
```

veya dogrudan: `EnterWorktree({ name: "<isim>" })`. Session cwd otomatik worktree'ye gecer.

Worktree adini ve path'ini **not al** — `/tmp/<isim>/` hem takip raporunun hem (Adim 4) kanit klasorunun yeridir.

### Takip raporunu HEMEN olustur ve ac

Analize **baslamadan once** `/tmp/<isim>/REPORT.md` dosyasini olustur ve `zed` ile ac.
Bu rapor **sadece takip icindir** — kullanici isterse canli izler. Asla onay beklenmez,
rapor olusturuldugu icin durulmaz; bulgular kesinse bu rapor uzerinden durmadan devam edilir.

```bash
EVID=/tmp/<isim>
mkdir -p "$EVID"
cat > "$EVID/REPORT.md" <<'EOF'
# Issue Workflow — <isim>

> Canli takip raporu. Calisma ilerledikce guncellenir. Onay/etkilesim icin DEGIL, sadece izleme icin.

## 1. Anlik Bulgular
_(analiz ilerledikce buraya islenir — gozlemler, hipotezler, denenenler)_

## 2. Final Rapor
_(calisma bitince temiz ozet buraya yazilir)_
EOF
zed "$EVID/REPORT.md"
```

Iki bolum:
- **1. Anlik Bulgular** — Adim 2 boyunca her yeni gozlem/hipotez/dogrulama `Edit` ile eklenir (akan kayit, dagillik normal)
- **2. Final Rapor** — Adim 2 sonunda temiz, ozet final yazilir (kok neden + cozum + yan etki + kesinlik)

### Hedefi `/goal`'a baglamayi oner (opsiyonel — `workflow` kurali)

Kullanicinin verdigi hedef **dogrulanabilir tek bir bitis durumuna** sahipse (orn "ticket'taki tum
adimlar gecene kadar duzelt", "test suite yesil olana kadar migrate et", "verilen 3 hatanin hepsi
giderilene kadar"), bu hedefi `/goal` ile koşula baglamayi **kullaniciya oner** — kendin set etme.
`/goal` Claude'u koşul saglanana kadar turlar arasi otonom calistirir (her tur kucuk model denetler).

`AskUserQuestion` ile sor:
- header: "Goal"
- question: "Bu issue'yu `/goal` ile koşula baglayip kanit/onay asamasina kadar otonom ilerleteyim mi?"
- options: ["Evet, /goal ile bagla", "Hayir, normal akis"]

Onay gelirse koşulu somut yaz — orn `/goal fix-<ref> worktree'sinde kok neden duzeltildi, ilgili test
PASS ($EVID/test-output.txt), gorsel degisiklikte before/after screenshot uretildi; veya 20 turdan
sonra dur`. Evaluator komut calistirmaz; koşulu Adim 4 kanit dosyalarinin transcript'e yansiyan
ciktilariyla **kanitlanabilir** yaz. **Onay sorulari (Adim 3 plan onayi, Adim 5 kanit onayi) hedefi
bozmaz** — `/goal` o turlarda da kullaniciya doner; otonomi yalnizca onay arasi adimlari hizlandirir.

> Hedef tek-shot/kucukse veya bitis durumu oznelse `/goal` ONERME — Adim 1'deki REPORT takibi yeterli.

---

## Adim 2 — Kok-neden analizi (ultrathink — `effort: max`, ANA AJAN)

> Bu adimda **derin dusun**. Skill frontmatter'i `effort: max` ile ultrathink'i zaten aktif eder.
> Yuzeysel ilk hipotezde durma — kodu/logu/sorunu **gerekli gordugun kadar** incele.
> **Sub-agent kullanma** — analizi ana ajan kendi context'inde yapar (yukaridaki yasak). Kod okuma,
> hipotez kurma ve dogrulama `Task`'a degil dogrudan `Grep`/`Read`/`Bash`'e dayanir.

1. Ilgili kodu oku (`Grep`/`Glob`/`Read`) — call site'lar, ilgili model/handler/serializer
2. Sorunu **uret/dogrula** — mumkunse hatayi yeniden gozlemle (log, test, API cagrisi)
3. **Kok nedeni** belirle — semptom degil, sebebi. Birden cok hipotez varsa her birini ele/dogrula
4. Yan etki yuzeyini cikar — bu degisiklik baska neyi etkiler?

> Analiz boyunca her anlamli gozlem/hipotez/dogrulamayi `REPORT.md`'nin **"1. Anlik Bulgular"**
> bolumune `Edit` ile **akarken** isle. Bu canli kayit takip icindir — yazmak icin durma/sorma.

**Analiz bitince** `REPORT.md`'nin **"2. Final Rapor"** bolumunu temiz doldur (ayrica kullaniciya da goster):
- Kok neden (kanitiyla: hangi satir/log/davranis)
- Onerilen cozum (somut: hangi dosyada ne degisecek)
- Yan etki / risk degerlendirmesi
- **Kesinlik**: KESIN | BELIRSIZ

> Rapor **onay mekanizmasi DEGIL** — final yazildi diye durma, dogrudan Adim 3'e (plan modu) gec.
> Kesinlik KESIN olsa da BELIRSIZ olsa da fark etmez; bir sonraki adimda plan moduna girilip cozum
> plani kullaniciya sunulur. Raporu ayrica burada kullaniciya gostermen yeterli — "onayliyor musun?"
> diye burada SORMA, onay plan modunda (Adim 3) alinir.

---

## Adim 3 — Plan moduna gec ve plan onayi al (HER DURUMDA)

Final rapor yazilinca **kesinlik fark etmeksizin** (KESIN de BELIRSIZ de) plan moduna gir ve cozum
planini kullaniciya onaya sun. Eski "KESIN ise sormadan uygula / BELIRSIZ ise AskUserQuestion ile sor"
karar mekanizmasi **kaldirilmistir** — tek onay noktasi plan modudur.

```
EnterPlanMode()
```

Plan modu sistem mesajinda belirtilen **plan dosyasina** cozum planini yaz; Adim 2'nin kok-neden
analizinden ureyen somut adimlari icersin:
- **Kok neden** (1-2 cumle, kanitiyla)
- **Yapilacak degisiklikler** (hangi dosyada ne degisecek — madde madde)
- **Yan etki / risk** ve nasil dogrulanacagi
- **Kesinlik** ve varsa **belirsizlik/alternatif yollar** (kullanicinin karar vermesi gereken noktalar)

Belirsizlik varsa once `AskUserQuestion` ile alternatifleri netlestir (plan modu icinde), sonra
plani kesinlestir. Plan hazir olunca onay iste:

```
ExitPlanMode()
```

> `ExitPlanMode` plani dosyadan okur ve kullanicidan onay ister — ayrica `AskUserQuestion` ile
> "onayliyor musun?" diye **SORMA**, onay bu adimda alinir. Plan onaylaninca uygulamaya gecilir.

Uygularken `coding` kurallarina uy: hata wrap, TODO yorumlari, gereksiz workaround yok,
"daha zarif yol var mi?" self-check.

---

## Adim 4 — Test ortamini hazirla, calistir, kanit topla, kapat

Calisma tamamlaninca cozumu **calisan uygulamada** test et ve kanitla. Klasor:

```bash
EVID=/tmp/<isim>
mkdir -p "$EVID"
```

### 4a. Test ortamini worktree'de hazirla

Worktree izole bir kopyadir — uygulamayi **burada** kur ve calistir (ana checkout'a dokunma).
Komutlar `CLAUDE.local.md` **"## Issue Workflow"** alanindan gelir (Adim 0a); yoksa proje tipinden cikar.

```bash
# Bagimlilik kurulum (worktree icinde, gerekiyorsa) — orn:
#   Python:  uv venv && source .venv/bin/activate && uv pip install -r requirements.txt
#   Node:    npm install
#   Go:      go build ./...
```

### 4b. Unique port ile ARKA PLANDA calistir

Ana checkout'taki dev server ile cakismamak icin **unique port** sec ve uygulamayi
**`run_in_background: true`** ile baslat. PID/port'u `$EVID/`'ye not al.

```bash
PORT=$(python3 -c "import socket;s=socket.socket();s.bind(('',0));print(s.getsockname()[1]);s.close()")
echo "$PORT" > "$EVID/.port"
# Arka planda baslat (run_in_background: true) — orn:
#   Django: .venv/bin/python manage.py runserver 127.0.0.1:$PORT 2>&1 | tee $EVID/server.log
#   Node:   PORT=$PORT npm run dev 2>&1 | tee $EVID/server.log
```

Bound port'u bekle (`curl --retry` veya port-check), hazir olunca testlere gec.

### 4c. Testleri yap + kanit topla

Soruna uygun araclarla kanit uret (her birini `$EVID/` altina dosya olarak yaz):

| Sorun tipi | Kanit araci | Cikti |
|---|---|---|
| **Gorsel / UI / akis** | `playwright-cli` skill (`PORT`'a baglan) | `$EVID/screenshot-*.png`, adim adim snapshot |
| API / backend endpoint | `curl`/`Bash` (`localhost:$PORT`) | `$EVID/api-before.json`, `$EVID/api-after.json` |
| Mantik / fonksiyon | test (`pytest`/`npm test`) | `$EVID/test-output.txt` (PASS) |
| Veri / DB / log | shell sorgu | `$EVID/query-result.txt` |
| Her durum | before/after diff | `$EVID/diff.txt` (`git diff > ...`) |

> **Gorsel degisiklik varsa GORSEL KANIT ZORUNLU.** Degisiklik UI/render/stil/akisi etkiliyorsa
> `playwright-cli` ile **mutlaka** ekran goruntusu al — mumkunse before/after (`screenshot-before.png`
> / `screenshot-after.png`). Gorsel kanit olmadan gorsel bir cozum "kanitlanmis" sayilmaz.

Ayrica `$EVID/SUMMARY.md` yaz:
- Kok neden (1-2 cumle)
- Yapilan degisiklik (dosya + ozet)
- Her kanit dosyasinin neyi ispatladigi (orn "api-after.json — artik 200 donuyor, onceden 500")

### 4d. Arka plandaki uygulamayi DURDUR (ZORUNLU)

Testler bitince **arka planda calisan uygulamayi mutlaka durdur** — orphan process/port birakma.
`KillShell`/ilgili background task'i sonlandir; gerekirse `kill $(lsof -ti tcp:$PORT)` ile port'u bosalt.
Playwright session aciksa `playwright-cli close` ile kapat. Bu adim hata/iptal durumunda da yapilir.

> Kanit dosyalari canli credential/JWT icerebilir → her zaman `/tmp` altinda, **repo disi**.

---

## Adim 5 — Kanit klasorunu ac ve onay bekle

```bash
zed /tmp/<isim>
```

Sonra `AskUserQuestion` ile onay iste:
- header: "Onay"
- question: "Kanitlari inceledin mi? Cozum onaylaniyor mu?"
- options: ["Evet, commit'e gec", "Hayir, degisiklik gerek", "Iptal"]

**Evet** → `commit` skill'e delege et (teslimat: commit/push/PR; tum kontrolleri o yapar).
Worktree'den PR icin `worktree` skill `pr <isim>` akisi kullanilabilir.
**Hayir** → geri bildirimi al, Adim 2-4'e don.
**Iptal** → worktree'yi `ExitWorktree({ action: "keep" })` ile birak, durumu rapor et.

---

## Akis Ozeti

```
0a. CLAUDE.local.md "## Issue Workflow" alanini oku  (varsa proje-ozel komut/port/test/akis notu)
0b. Kaynagi tam analiz et + contexte al              (plane-cli / Read / markitdown / WebFetch / diji-log-search)
1.  Worktree ac + /tmp/<isim>/REPORT.md ac           (worktree skill; REPORT zed — takip icin, onay DEGIL)
    └─ Hedef dogrulanabilir+coktur ise `/goal`'a baglamayi ONER (opsiyonel; workflow kurali)
2.  Kok-neden analizi — ULTRATHINK                   (effort: max; canli "Anlik Bulgular" → "Final Rapor")
3.  Plan moduna gec — EnterPlanMode → plan yaz → ExitPlanMode onayi  (her durumda; eski KESIN/BELIRSIZ karari kalkti)
4.  Test ortami hazirla → unique port + arka plan → test → kanit (gorsel degisiklikte SCREENSHOT zorunlu) → uygulamayi DURDUR
5.  zed ile ac → AskUserQuestion onay → commit skill
```

> REPORT.md (takip, onay beklemez) ile Adim 5 kanit-onayi farkli seylerdir: rapor analizi izlemek
> icin akarken yazilir; Adim 5 onayi cozum uygulandiktan sonra kanitlar uzerinden alinir.

## Entegrasyon Notlari

- **Worktree**: mantik `worktree` skill'de — bu skill sadece `new <isim>` cagirir, isim turetir
- **Teslimat**: commit/push/PR mantigi `commit` skill'de — `before-commit` kurali geregi manuel git yok
- **Log analizi**: diji b2c projede `diji-log-search` skill'e delege (basket lifecycle)
- **Kaynak donusum**: PDF/Office → `markitdown`, URL → `WebFetch`, gorsel → `Read`
- **Local alan**: `CLAUDE.local.md` **"## Issue Workflow"** bolumu ise baslarken (Adim 0a) okunur — proje-ozel baslatma/test/port komutlari ve kullanici-ozel akis notlari oraya yazilir
- **Test ortami**: worktree'de izole hazirlanir, **unique port** ile arka planda (`run_in_background`) calisir, testler bitince **mutlaka durdurulur** (orphan process yok)
- **Gorsel kanit**: gorsel/UI degisikliginde `playwright-cli` ekran goruntusu **zorunlu** (mumkunse before/after)
- **Takip raporu**: `/tmp/<isim>/REPORT.md` calisma basinda olusur, zed ile acilir, analiz akarken guncellenir — yalniz **izleme** icindir, hicbir adimda onay/etkilesim beklemez
- **Kanit izolasyonu**: her zaman `/tmp/<isim>/` — repo'ya kanit/credential sizmaz
- **Plan onayi**: Adim 2 final raporu sonrasi **her durumda** plan moduna girilir (`EnterPlanMode` → plan dosyasina cozum plani → `ExitPlanMode` onayi); eski "KESIN→uygula / BELIRSIZ→sor" karari kaldirildi, tek onay noktasi plan modudur
- **Karar felsefesi**: muhafazakar — plan onaylanmadan uygulamaya gecilmez; belirsizlik varsa plan modunda `AskUserQuestion` ile netlestir (`ask-first` kurali)
- **Hedef baglama (`/goal`)**: hedef dogrulanabilir tek bitis durumuna sahip + cok turlu ise Adim 1'de `/goal`'a baglamayi ONER (set etme, kullanici onayiyla); koşulu Adim 4 kanit ciktilariyla kanitlanabilir yaz (`workflow` kurali)
- **Sub-agent siniri**: Adim 0b (kaynak analizi) ve Adim 2 (kok-neden) **asla** `Task`/sub-agent'a verilmez — baglamdan kopar, kritik analiz bozulur. `Task` yalniz `obsidian-searcher` on aramasi ve Adim 4 kanit-uretiminde (playwright vb.) kullanilabilir

## Ek — `CLAUDE.local.md` "## Issue Workflow" Sablonu

Bu bolumu calisilan projenin `CLAUDE.local.md`'sine ekle (proje-ozel; commit edilmez). Skill Adim 0a'da okur.

```markdown
## Issue Workflow

- **Bagimlilik kurulum**: <orn `uv venv && source .venv/bin/activate && uv pip install -r requirements.txt`>
- **Baslatma komutu**: <orn `.venv/bin/python manage.py runserver 127.0.0.1:$PORT`>
- **Test komutu**: <orn `pytest`, `npm test`, `playwright test`>
- **Port**: unique (otomatik) | sabit gerekiyorsa: <port>
- **Ek servisler**: <orn redis/postgres gerekli mi, nasil ayaga kalkar>
- **Akis notlari**: <bu projede dikkat edilecekler, kullanici-ozel kurallar>
```
