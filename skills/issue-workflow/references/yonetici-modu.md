# Yonetici Modu — Tek Workflow, Sonda Tek Kontrol

`issue-workflow` Adim 4.5'te yonetici modu secildiyse bu dosya gecerlidir. **Adim 7'nin yerine
gecer** (7Y); diger adimlar (1-6, 8, 8.5, 9, 10) aynen kalir. Tek worktree kullanilir.

**Ozet:** tum is **tek `Workflow` script'inde** fazlanarak yazilir. Agent'lar yalniz kod yazar.
Is bitince ana agent **bir kez** dogrular (build + test + lint), hatalari fix workflow'a dagitir,
kaniti kendisi uretir. Code-review **Adim 9'da `commit` skill'de** kosar — akista ikinci bir
review yoktur.

---

## 1. Ilkeler (esnetilmez)

1. **Ara kontrol yok.** Ara commit, ara build, ara review, asamali teslim YAPILMAZ. Surec icinde
   kirik noktalar normaldir; is **sonda** duzgun olsun yeter. Tek PR acilir.
2. **Tum is tek workflow.** Fazlar script icinde ardisik `phase()` bloklaridir. Ikinci bir
   uygulama workflow'u ve paralel workflow YOKTUR.
3. **Sozlesme fazi zorunlu ilk fazdir.** Butunlugu ara build degil bu saglar (Bolum 3).
4. **Agent'lar yalniz yazar.** test/build/lint/format/git/uygulama-baslatma yasak; salt-okuma
   self-check serbest.
5. **Dogrulama ve kanit ana agentta**, isin sonunda, tek seferde.
6. **Ana agent is bitene kadar durmaz** — garantisi watchdog dongusudur (Bolum 8).

---

## 2. Akis

```
[Ana agent] WATCHDOG KUR (Bolum 8) — ilk is
   |
   +-> TEK Workflow: phase('Sozlesme') -> phase('Faz A') -> phase('Faz B') -> ...   (Bolum 3-4)
   |
   +-> bitis bildirimi -> ARA RAPOR YAZMA, dogrudan dogrulamaya gec
   |
   +-> DOGRULA (Bolum 5): git diff + build + test + lint   [ana agent, arka plan, cikti $EVID/*.log]
   |
   +-> hata varsa -> FIX WORKFLOW (Bolum 6) -> tekrar dogrula   (yesile donene kadar; tur>=3 -> DUR, bildir)
   |
   +-> KANIT (Adim 7a-7d, ana agent): uygulamayi ayaga kaldir, screenshot/API/test, DURDUR
   |
   +-> `.done` yaz (watchdog kapanir) -> Adim 8 (B8-B11) -> 8.5 -> 9 commit skill (review + tek PR)
```

**Durum takibi**: `TaskCreate`/`TaskUpdate` (faz basina bir gorev) + `~/.pa-render/active/<isim>/faz-durumu.html`
(PA Render ek dosyasi — klasor imzasi max mtime oldugu icin her guncellemede dashboard tazelenir).
Ara commit olmadigi icin **kalici kayit worktree'nin kendisidir**; iş sonda tek commit'le kayda gecer.

---

## 3. Sozlesme fazi — ara build'in yerine gecen mekanizma

Workflow'un **ilk fazi tek agent**tir ve yalnizca **iskeleti** uretir; is mantigi yazmaz:

- Fonksiyon/metot/sinif **imzalari**, tip tanimlari, arayuz/protokol tanimlari
- Endpoint/route semasi, request-response sekilleri
- Modul dosyalari (bos govde, `TODO: <gorev kodu>` isaretiyle), import iskeleti
- Sabitler, enum'lar, hata tipleri, migration numara blogu

Sonraki fazlarin agent'lari **once bu dosyalari okur**, sonra kendi govdesini doldurur. Birbirlerini
gormeden uyumlu kod yazmalarinin sebebi budur — ara build'in yapmaya calistigi butunluk kontrolunu
**onceden** saglar.

- Model/effort: `opus` + **`high`** — sonraki her sey buna bagli, tek yer burada dusunulur
- Sozlesme fazi ciktisi (`files_changed`) sonraki fazlarin brief'ine **acikca** yazilir
- Sozlesme disina cikmak gerekiyorsa agent bunu `open_questions`'a yazar, kendi kafasina gore
  imza degistirmez

---

## 4. Workflow script'i

Tum is **tek inline `script`** ile calisir. Tool script'i oturum dizinine kaydeder ve `scriptPath`
doner; asilma/duzeltme durumunda `scriptPath` + `resumeFromRunId` ile devam edilir (degismeyen
`agent()` cagrilari onbellekten gelir).

```js
export const meta = {
  name: '<konu>-uygulama',
  description: '<isin tamami tek cumleyle>',
  phases: [
    { title: 'Sozlesme', detail: 'imza/tip/sema iskeleti — tek agent' },
    { title: 'Faz A', detail: '<n> gorev, dosya-ayrik' },
    { title: 'Faz B', detail: 'A bittikten sonra' },
  ],
}

const RAPOR = {
  type: 'object',
  required: ['gorev', 'status', 'files_changed', 'summary'],
  properties: {
    gorev: { type: 'string' },
    status: { type: 'string', enum: ['done', 'blocked'] },
    files_changed: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    assumptions: { type: 'array', items: { type: 'string' } },
    open_questions: { type: 'array', items: { type: 'string' } },
  },
}

phase('Sozlesme')
const sozlesme = await agent(`<sozlesme brief'i — Bolum 5>`, {
  label: 'sozlesme', phase: 'Sozlesme', model: 'opus', effort: 'high', schema: RAPOR,
})
const iskelet = (sozlesme?.files_changed || []).join(', ')

const FAZLAR = [
  { ad: 'Faz A', gorevler: [ { kod: 'G1', brief: `...` }, { kod: 'G2', brief: `...` } ] },
  { ad: 'Faz B', gorevler: [ { kod: 'G3', brief: `...` } ] },
]

const cikti = []
for (const f of FAZLAR) {
  phase(f.ad)
  const sonuc = await parallel(f.gorevler.map(g => () =>
    agent(`${g.brief}\n\nSOZLESME DOSYALARI (once oku): ${iskelet}`, {
      label: `${f.ad}:${g.kod}`, phase: f.ad, model: 'opus', effort: 'medium', schema: RAPOR,
    })
  ))
  cikti.push({ faz: f.ad, gorevler: sonuc.filter(Boolean) })
  log(`${f.ad} bitti — ${sonuc.filter(Boolean).length}/${f.gorevler.length}`)
}
return { sozlesme, fazlar: cikti }
```

### Faz kurma
- Bir gorevin ciktisi digerinin girdisiyse ayni fazda olamaz → sonraki faz
- Ayni dosyaya yazan iki gorev ayni fazda **paralel** olamaz: birlestir ya da ardisik `await agent()`
- Her gorevin **yazabilecegi dosya yollari** planda (Adim 5) belirlenmistir

### Tavan (M1 Pro 8 cekirdek / 16 GB)
- Bir `parallel()` blogunda **<= 6 agent** — harness cap'i `min(16, cekirdek-2)`; fazlasi kuyruk olur
- Workflow toplaminda **<= 15 agent**; is daha buyukse **daha cok `phase()` blogu** ekle,
  esszamanli agent sayisini artirma
- `pipeline()` item bazinda zincir gerektiginde kullanilir (bariyersiz, en hizlisi)

### Model + effort (her cagrida acik yazilir)
| Is | model | effort |
|---|---|---|
| Sozlesme fazi | `opus` | `high` |
| Kod yazma / refactor / test yazimi / fix | `opus` | `medium` |
| Mekanik (rename, tasima, sablon) | `sonnet` | `low` |
| Salt-okunur envanter/arama | `sonnet` | `low` |

⛔ Fable oturumunda hicbir `agent()` fable ile kosmaz (ust sinir `opus`); `haiku` kullanilmaz;
named workflow dogrudan launch edilmez (`token-efficiency`).

---

## 5. Agent brief sablonu

```
Sen <FAZ>/<KOD> gorevini uyguluyorsun: <alan adi>.

CALISMA DIZINI
- <worktree yolu> — zaten hazir. Worktree/branch ACMA, dizin degistirme.

SOZLESME
- Once su dosyalari OKU ve imzalara birebir uy: <sozlesme dosyalari>
- Imza degistirmen gerekiyorsa DEGISTIRME — open_questions'a yaz.

HEDEF
<tek paragraf: ne bitmis olacak>

KAPSAM (bunlar ve yalniz bunlar)
- <madde>

KAPSAM DISI
- <acikca yapilmayacaklar>

DOSYA SINIRI
- Yazabilecegin yollar: <liste>
- DOKUNMA: <liste>

KURALLAR
- Proje anayasasi gecerlidir: CLAUDE.md + CLAUDE.local.md + ~/.claude/rules/
  (hata wrap, TODO yorumu, workaround yok; Ingilizce kod yorumu).
- Kritik akis noktalarina [<SESSION_NAME>] prefix'li log ekle (dilin logger'i varsa).
- Yazdiktan sonra dosyalarini Read ile geri okuyup tutarliligi kontrol et (import/isim/imza).
  Bu SALT-OKUMA kontroldur.

YASAKLAR (kesin)
- test / build / derleme / lint / format / type-check CALISTIRMA
- git komutu YOK, uygulama BASLATMA, paket kurma YOK
- Dosya sinirin disina yazma
- Bunlarin hepsini ana agent SONDA tek seferde yapacak — senin isin yalniz kodu dogru yazmak

BELIRSIZLIK
- Durma: en makul varsayimla ilerle ve `assumptions`a yaz; cozulemeyen engelde status="blocked".

RAPOR: son mesajin SADECE verilen JSON semasi olsun.
```

Sozlesme fazi brief'i ayni sablonu kullanir, farki: "yalnizca iskelet uret — imza, tip, sema, bos
govde + `TODO: <kod>`; is mantigi YAZMA" ve kapsam olarak **tum modulleri** gormesi.

---

## 6. Dogrulama (ana agent, sonda, tek sefer)

Sirayla — hepsi **arka planda**, ciktilar dosyaya:

```bash
EVID=~/.pa-render/active/<isim>
git diff --stat                                   # iddia edilen dosyalar gercekten degisti mi
heavy <build komutu>  > "$EVID/build.log" 2>&1    # agir derleme heavy ile (heavy-build kurali)
heavy <test komutu>   > "$EVID/test.log"  2>&1
<lint/type-check>     > "$EVID/lint.log"  2>&1
```

- **Paralel dagitma**: bu makinede `HEAVY_SLOTS=1` — build/test paralel agent'lara verilse de tek
  slotta siraya girer, hiz kazanci yok, ustune agent maliyeti biner. Ana agentta kalir.
- Ana agent **tum logu context'e almaz**: `tail`/`grep -c error` ile ozet okur; ham cikti fix
  agent'ina **dosya yolu olarak** verilir, agent kendisi okur.
- `git status --short` ile beklenmeyen dosya degisikligi (dosya siniri ihlali) kontrol edilir.

---

## 7. Fix workflow

Dogrulama hatalari **dosya bazinda gruplanir**, her grup bir `agent()`:

```js
export const meta = { name: '<konu>-fix', description: 'dogrulama hatalarini gider',
  phases: [{ title: 'Fix' }] }

phase('Fix')
const sonuc = await parallel(GRUPLAR.map(g => () =>
  agent(`Su dosyalardaki hatalari gider: ${g.dosyalar.join(', ')}
Hata ciktisi: ${g.logYolu} — bu dosyayi OKU, ilgili satirlari bul.
Yasaklar ayni: test/build/lint/git YOK, sadece kodu duzelt.`,
    { label: `fix:${g.ad}`, phase: 'Fix', model: 'opus', effort: 'medium', schema: RAPOR })
))
```

- **Ayni dosyaya iki fix agent'i yazmaz** — gruplama dosya bazlidir
- Fix bitince **Bolum 6 tekrar kosar**; yesile donene kadar dongu
- **Tur >= 3** ve hala yesil degilse DUR, `AskUserQuestion` ile kullaniciya bildir (dongu korumasi)
- Kucuk hata (<=3 satir, tek dosya) icin workflow kurma — ana agent inline duzeltir, kurulum
  maliyeti hatadan pahalidir
- **Mimari ihlal** (guvenlik acigi, yanlis pattern, para icin float, auth'suz uc): DUR ve sor
  (`coding` kurali)

---

## 8. Watchdog — ana agent uyumasin

`Monitor` ile nabiz izleyici; **7Y'nin ilk isi**:

```bash
EVID=~/.pa-render/active/<isim>
mkdir -p "$EVID" && rm -f "$EVID/.done" && touch "$EVID/.heartbeat"
```

```bash
EVID=~/.pa-render/active/<isim>
wait=60
while [ ! -f "$EVID/.done" ]; do
  now=$(date +%s)
  hb=$(stat -f %m "$EVID/.heartbeat" 2>/dev/null || echo "$now")
  age=$(( now - hb ))
  if [ "$age" -gt 180 ]; then
    echo "UYANDIRMA (${age}s hareketsiz) — is yarim. faz-durumu.html + git diff oku, DEVAM ET."
    wait=$(( wait * 2 )); [ "$wait" -gt 300 ] && wait=300
  else
    wait=60
  fi
  sleep "$wait"
done
echo "WATCHDOG KAPANDI"
```

`Monitor({ command: <yukaridaki>, description: "yonetici modu watchdog — <isim>", persistent: true })`

- Her turun ilk Bash cagrisinda `touch "$EVID/.heartbeat"`
- Kapanis: `touch "$EVID/.done"` — is bitti, sert durak veya kullanici kesintisi. Sert duraktan
  sonra devam edilecekse `.done` silinip watchdog yeniden kurulur
- `.heartbeat`/`.done` dotfile'dir — PA Render dosya panelinde gorunmez

### Turu kapatmanin izin verilen uc hali
1. Is bitti, Adim 8 sohbet kapisina gelindi
2. Sert durak (mimari ihlal, 3 tur cozulemeyen hata, kullanici karari gerektiren belirsizlik)
3. Kullanici akisi kesti

Disinda tur kapatilmaz: bildirim geldiginde ara rapor yazilmaz, dogrudan sonraki adima gecilir;
arka planda is varken bosta durulmaz (`faz-durumu.html` guncellenir, fix script'i hazirlanir);
asilma supheli ise `TaskList`/`BashOutput` ile taranir, `resumeFromRunId` ile surdurulur.
On planda `sleep` kullanilmaz.

---

## 9. Kanit ve kapanis

**Kanit ana agentta uretilir** (standart Adim 7a-7d): worktree'de bagimlilik kurulumu → unique port
+ arka planda uygulama → screenshot/API/test ciktilari `$EVID/` altina → **uygulamayi durdur**.

- Workflow'a dagitilmaz: `playwright-cli` tek tarayici ornegi yonetir (`open`/`close` global),
  paralel agent'lar ayni oturumu bozar; ayrica uygulamayi ayakta tutan/kill eden taraf tek olmali,
  yoksa orphan port kalir.
- Gorsel degisiklikte screenshot **zorunlu**.

Sonra: `.done` → **Adim 8** (B8-B11; B9'da kanitlar, B8'de faz kirilimi) → **Adim 8.5**
(`[SESSION_NAME]` temizligi) → **Adim 9** (`commit` skill: code-review + tek commit + tek PR +
Plane kapama) → **Adim 10** (arsivle).

---

## 10. Durustluk

- "Workflow bitti" kanit degildir — kanit `git diff` + kosturulan komutun ciktisidir.
- Agent'in `assumptions`/`open_questions` alanlari okunur ve raporlanir; is akisini degistiren bir
  varsayim analiz sayfasina islenir.
- Bir faz kismen bittiyse "bitti" denmez; ne bitti / ne kaldi ayri yazilir.
- Sonda tek kontrol yapiliyor diye kontrol **hafifletilmez**: build, test, lint ve review'in
  tamami kosar.
