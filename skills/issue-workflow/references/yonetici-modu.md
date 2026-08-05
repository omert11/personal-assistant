# Yonetici Modu — Fazli Workflow + Tek Kontrol Noktasi

`issue-workflow` Adim 4.5'te yonetici modu secildiyse bu dosya gecerlidir. Standart akisin
**Adim 7'si** burada tarif edilen **7Y** ile degistirilir; diger adimlar (1-6, 8, 8.5, 9, 10)
aynen kalir. **Tek worktree** kullanilir — Adim 5 degismez.

**Ozet:** ana agent isi fazlara boler, her fazi **bir `Workflow` script'iyle** uygulatir, sonra
**tek noktada kendisi dogrular** (build + test + lint + code-review), gerekirse duzeltir, faz sonu
checkpoint commit atip push eder, sonraki faza gecer. Tum fazlar bitince kanitlari toplar.

> **Delegasyonun tek yolu `Workflow` script'idir.** Ad-hoc `Agent` cagrisi, `SendMessage` turlari,
> uzun omurlu "yonetici agent" YOK. Workflow da subagent kosar — fark, agent'larin **script'le
> sinirlanmis, tek gorevli ve `schema` ile kisa JSON donen** olmasi: ham transcript ana context'e
> girmez, tur sayisi ongorulebilir kalir.
>
> Skill talimati Workflow cagirmayi soyledigi icin bu **gecerli bir opt-in**'dir — kullanicidan
> ayrica izin istenmez.

---

## 1. Ne zaman yonetici modu

| Durum | Mod |
|---|---|
| Tek is paketi, dar kapsam, tek dosya kumesi | **Tek akis** (Adim 7 aynen) |
| 2+ ayrik gorev veya sirali bagimlilik iceren orta/buyuk is | **Yonetici modu** |

Orta ve buyuk isler icin varsayilan budur. Tereddutteysen yonetici modu sec — fazlama ve tek
kontrol noktasi, isi tek elden yurutmekten hem hizli hem daha derli topludur.

---

## 2. Ilkeler (esnetilmez)

1. **Ana agent yonetir, agent'lar yalniz yazar.** Hicbir agent test/build/lint/format/commit/
   git/review calistirmaz — hepsi ana agentta, **faz sonunda tek seferde**.
2. **Tek worktree.** Ek worktree, ek branch, merge turu yok.
3. **Faz = sirali bagimlilik siniri.** Faz icindeki gorevler birbirinden bagimsiz ve **dosya-ayrik**tir.
4. **Fazlama workflow'un ICINDE yapilir.** Sirali fazlar ayri ayri workflow'lara bolunmez —
   tek script `phase()` + ardisik `parallel()` bloklariyla bir kac fazi pes pese kosturur.
   **Paralel workflow YOK** (bkz. Bolum 4).
5. **Bir workflow = bir dogrulama birimi.** Dogrulama + checkpoint commit workflow **bitiminde**
   yapilir, her faz sonunda degil — ara duraklar isi yavaslatir.
6. **Duzeltme ucuz tarafta yapilir**: kucuk bulgu ana agentta, buyuk bulgu seti fix workflow'da.
7. **Ana agent is bitene kadar durmaz** — turu ara raporla kapatmaz (Bolum 11).

---

## 3. Adim 7Y — Akis

```
[Ana agent] plandaki fazlari sirala (Adim 5'te belirlendi)
   |
   +-> fazlari DOGRULAMA BIRIMLERINE grupla (2-4 faz = 1 workflow, Bolum 4)
   |
   +-> birimin script'ini yaz: phase('Faz A') parallel[...] -> phase('Faz B') parallel[...]
   |   -> Workflow baslat (TEK workflow; paralel workflow yok)
   |
   +-> bitis bildirimi geldi -> ARA RAPOR YAZMA, hemen dogrulamaya gec
   |
   +-> ciktilari DOGRULA (git diff: dosyalar gercekten degisti mi)
   |
   +-> build + test + lint  (heavy kurali: agir derleme `heavy` + arka plan)
   |
   +-> code-review (ayri claude oturumu, arka plan — Bolum 7)
   |
   +-> bulgu: <=3 bulgu veya tek dosya -> ana agent inline duzeltir
   |          daha buyuk           -> fix workflow (dosyaya gore dagit)
   |
   +-> checkpoint commit + push  (Bolum 8)
   |
   +-> sonraki dogrulama birimi — AYNI TURDA baslat (Bolum 11)
   |
   +-> tum fazlar bitti -> kanit toplama (Adim 7a-7d, ana agent) -> Adim 8
```

### Durum takibi — uc katman

| Katman | Nerede | Ne zaman |
|---|---|---|
| **Oturum ici canli** | `TaskCreate`/`TaskUpdate` — her dogrulama birimi bir gorev | Workflow basi `in_progress`, commit sonrasi `completed` |
| **Ekranda gorunur** | `~/.pa-render/active/<isim>/faz-durumu.html` (PA Render **ek dosya**) | Workflow basi + dogrulama + commit (asagi) |
| **Kalici kayit** | Checkpoint commit + push (`wip(<birim>): …`) | Birim yesile donunce |

Faz faz ilerleme ayrica `/workflows` agacinda canli gorunur (`phase()` gruplari) — ana agent
buraya bakmak icin durmaz, workflow bitis bildirimini bekler.

#### `faz-durumu.html` — PA Render ek dosyasi

Analiz sayfasiyla **ayni klasorde ama ayri dosya**: `index.html`'in B1..B11 yapisi kirlenmez,
dashboard'un sag **Dosyalar** panelinden tiklanip acilir. Konu imzasi klasordeki dosyalarin max
mtime'i oldugu icin dosya her guncellendiginde **SSE tetiklenir** — ekran kendini tazeler,
gorulmemis-degisiklik noktasi yanar. Kullanici faz ilerleyisini oradan izler.

Iskelet (`user-render` kit'i; `<style>` yazma):

```html
<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Faz Durumu — <isim></title>
<link rel="stylesheet" href="/lib/pa.css">
<script type="module" src="/lib/pa.js"></script>
</head>
<body>
<main>
  <header class="pa-head">
    <div class="eyebrow">Yonetici modu</div>
    <h1>Faz Durumu</h1>
    <div class="meta">
      <div class="cell"><span class="k">Worktree</span><span class="v mono"><isim></span></div>
      <div class="cell"><span class="k">Faz</span><span class="v">2 / 4</span></div>
    </div>
  </header>
  <div class="tablewrap"><table>
    <tr><th>Faz</th><th>Gorevler</th><th>Durum</th><th>Review</th><th>Commit</th></tr>
    <tr><td>A</td><td>G1, G2, G3</td><td><span class="badge ok">tamam</span></td>
        <td>2 bulgu / duzeltildi</td><td class="mono">a1b2c3d</td></tr>
    <tr><td>B</td><td>G4, G5</td><td><span class="badge info">kosuyor</span></td>
        <td class="muted">—</td><td class="muted">—</td></tr>
    <tr><td>C</td><td>G6, G7, G8</td><td><span class="badge muted">bekliyor</span></td>
        <td class="muted">—</td><td class="muted">—</td></tr>
  </table></div>
</main>
</body>
</html>
```

Durum degerleri: `bekliyor` (muted) · `kosuyor` (info) · `dogrulaniyor` (warn) · `duzeltme` (warn) ·
`tamam` (ok) · `bloke` (err).

**Guncelleme anlari** (her biri tek `Edit`; birimdeki tum fazlar tek satirda degil, faz basina satir):
1. Birimin workflow'u baslarken → birimdeki fazlar `kosuyor`
2. Workflow bitip dogrulama baslarken → `dogrulaniyor`; review bulgusu cikarsa `duzeltme` + bulgu ozeti
3. Checkpoint commit sonrasi → `tamam` + commit SHA'si

Arka planda is beklerken bu dosyayi guncellemek "bosta durmama" isinin parcasidir (Bolum 11).

Oturum olurse yeni oturum bu dosyadan + `git log`'dan devam eder — plan analiz sayfasinda,
nerede kalindigi burada.

### Ornek sıralama

```
Faz A: G1, G2, G3   Faz B: G4, G5   Faz C: G6, G7, G8   Faz D: G9, G10   Faz E: G11, G12

Birim 1 = Faz A + B + C   |   Birim 2 = Faz D + E

1. Workflow #1 (TEK cagri):  phase A -> parallel[G1,G2,G3]
                             phase B -> parallel[G4,G5]
                             phase C -> parallel[G6,G7,G8]
2. build + test + lint + code-review        (ilk ve tek durak)
3. gerekiyorsa fix workflow
4. checkpoint commit + push
5. Workflow #2 (TEK cagri):  phase D -> parallel[G9,G10]
                             phase E -> parallel[G11,G12]
6. build + test + lint + code-review -> fix -> commit + push
7. Kanit toplama -> Adim 8 (analiz sayfasi) -> 8.5 -> 9 (commit skill)
```

Eski (yanlis) desen: her fazi ayri workflow yapip her fazda durup dogrulamak. Bu her faz
arasinda bir baslatma + bekleme + dogrulama duragi uretir; is buyudukce duraklar isin kendisinden
uzun surer.

---

## 4. Fazlama, gruplama, tavan

### Faz kurma
- Bir gorevin **ciktisi** baska bir gorevin **girdisiyse** ayni fazda olamaz — sonraki faza gider
- Ayni dosyaya yazan iki gorev ayni fazda **paralel** olamaz: ya tek goreve birlestir ya da
  script icinde **ardisik** kostur (`await agent(A)` sonra `await agent(B)`)
- Her gorev icin **yazabilecegi dosya yollari** onceden belirlenir; ortusme yoksa paralel

### Fazlar workflow ICINDE zincirlenir
Sirali fazlar ayri workflow cagrilarina bolunmez. Tek script'te:

```js
phase('Faz A'); const a = await parallel([...])   // A biter
phase('Faz B'); const b = await parallel([...])   // B, A'nin ardindan
```

`parallel()` bir bariyerdir — bir sonraki `phase()` ancak oncekinin tamami bitince baslar, yani
sirali baglilik script icinde zaten korunur. Ana agent araya girmez, bekleme/baslatma duragi olusmaz.

Gorev basina zincir gerekiyorsa (A'nin ciktisi B'ye girdi, item bazinda) `pipeline()` kullan —
bariyersiz akar, en hizlisidir.

### Dogrulama birimi — kac faz bir workflow'a girer
Bir workflow = **bir dogrulama + commit birimi**. Olcut: *build/test'in anlamli sonuc verdigi en
kucuk butun*. Pratikte **2-4 mantiksal faz**.

| Durum | Ne yap |
|---|---|
| Fazlar ayni modulu/katmani tamamliyor | Ayni birime koy — arada dogrulamak bosuna durak |
| Bir faz mimariyi degistiriyor (sema, migration, ortak arayuz) | Kendi birimi olsun — hatasi sonrakileri komple bozar |
| Faz cikti uretmiyor, yalniz hazirlik (dosya tasima, rename) | Sonraki fazla ayni birime koy |
| Toplam gorev sayisi 15'i asiyor | Ikiye bol (oturum workflow buyuklugu rehberi: 15 agent alti) |

### Paralel workflow — YOK
Iki workflow ayni anda **calistirilmaz**. Gerekce: her workflow kendi esszamanlilik havuzunu acar,
iki tanesi makinenin cekirdek sayisini asar (`heavy-build` kurali) ve kazanc yerine swap uretir;
ayrica iki ayri bitis bildirimi ana agentta ek durak demektir. Ayrik isler **ayni script icinde**
ayri `phase()` bloklari olarak kosar.

### Agent tavani (M1 Pro 8 cekirdek / 16 GB)
- **Bir `parallel()` blogunda <= 6 agent** — harness cap'i zaten `min(16, cekirdek-2)` uygular;
  fazlasini vermek kuyruk olusturur, hiz kazandirmaz
- **Workflow toplaminda <= 15 agent** (oturumun workflow buyuklugu rehberi)
- Is bu tavanlari asiyorsa esszamanli agent artirma — **daha cok `phase()` blogu** ekle, ardisik kossunlar

---

## 5. Workflow script sablonu

Her **dogrulama birimi** icin (birkac faz birden) **inline `script`** ile `Workflow` cagrilir
(dosyaya yazma; tool script'i oturum dizinine kaydeder ve `scriptPath` doner — duzeltme gerekirse
`scriptPath` + `resumeFromRunId` ile degismeyen `agent()` cagrilari onbellekten gelir).

```js
export const meta = {
  name: 'birim-1-<konu>',
  description: '<birim tek cumleyle>',
  phases: [
    { title: 'Faz A', detail: '<n> gorev, dosya-ayrik' },
    { title: 'Faz B', detail: 'A bittikten sonra' },
    { title: 'Faz C', detail: 'B bittikten sonra' },
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

const FAZLAR = [
  { ad: 'Faz A', gorevler: [ { kod: 'G1', brief: `<agent brief'i — Bolum 6>` },
                             { kod: 'G2', brief: `...` } ] },
  { ad: 'Faz B', gorevler: [ { kod: 'G3', brief: `...` } ] },
  { ad: 'Faz C', gorevler: [ { kod: 'G4', brief: `...` } ] },
]

const cikti = []
for (const f of FAZLAR) {
  phase(f.ad)                                     // ilerleme agacinda ayri grup
  const sonuc = await parallel(f.gorevler.map(g => () =>
    agent(g.brief, { label: `${f.ad}:${g.kod}`, phase: f.ad, model: 'opus', schema: RAPOR })
  ))
  cikti.push({ faz: f.ad, gorevler: sonuc.filter(Boolean) })
  log(`${f.ad} bitti — ${sonuc.filter(Boolean).length}/${f.gorevler.length}`)
}
return { fazlar: cikti }
```

- `parallel()` bariyer oldugu icin faz sirasi script icinde korunur — **ana agent araya girmez**
- Bir onceki fazin ciktisi sonraki fazin brief'ine girecekse `f.gorevler` brief'ini dongude
  `cikti`'dan besle (ornegin uretilen dosya listesi)
- Item bazinda zincir gerekiyorsa `pipeline(items, stage1, stage2)` — bariyersiz, en hizlisi

- **Her `agent()` cagrisinda `model` acikca yazilir** (`token-efficiency` kurali). Kod/sema/test
  yazan → `opus`; yalnizca arama/envanter cikaran → `sonnet`. `haiku` kullanilmaz.
  ⛔ **Fable Model Baraji** (SKILL.md Adim 5) burada da gecerli: fable oturumunda hicbir `agent()`
  fable ile kosmaz, ust sinir `opus`.
- `schema` **her zaman** verilir — ana context'e ham metin degil, dogrulanmis JSON doner.
- Ayni dosyaya dokunan gorevler `parallel()` icinde degil, ardisik `await agent(...)` ile.
- Named/hazir workflow (`Workflow({name: ...})`) **launch edilmez** — script model override tasimaz.

---

## 6. Agent brief sablonu (script icinde)

```
Sen <FAZ>/<KOD> gorevini uyguluyorsun: <alan adi>.

CALISMA DIZINI
- <worktree yolu> — zaten hazir. Worktree/branch ACMA, dizin degistirme.

HEDEF
<tek paragraf>

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
- Yazdiktan sonra dosyalarini Read ile geri okuyup tutarliligi kontrol et
  (import/isim/imza tutuyor mu). Bu SALT-OKUMA kontroldur.

YASAKLAR (kesin)
- test / build / derleme / lint / format / type-check CALISTIRMA
- git komutu YOK (add/commit/push/checkout/stash/diff dahil), uygulama BASLATMA, paket kurma YOK
- Dosya sinirin disina yazma
- Bunlarin hepsini ana agent faz sonunda TEK SEFERDE yapacak — senin isin yalniz kodu dogru yazmak

BELIRSIZLIK
- Karar veremedigin bir sey varsa DURMA: en makul varsayimla ilerle ve `assumptions`a yaz;
  cozulemeyen engel varsa status="blocked" ve `open_questions`.
```

---

## 7. Faz sonu dogrulama (ana agent, tek nokta)

Sirayla:

1. **Cikti dogrulamasi** — `git status --short` + `git diff --stat`: raporda iddia edilen dosyalar
   gercekten degismis mi, fazladan ne degismis. (`workflow` kurali: agent ciktisi dogrulanana
   kadar guvenilmez.)
2. **Build / derleme** — agir derlemeler `heavy` sarmalayicisiyla ve arka planda (`heavy-build` kurali).
3. **Test** — proje test komutu (Adim 1'deki "## Issue Workflow" alanindan).
4. **Lint / format / type-check** — projede varsa.
5. **Code-review** — `token-efficiency` kurali geregi **ayri bir Claude oturumuna devredilir**:
   ```bash
   cd <worktree-yolu> && claude --model opus -p '/code-review medium'
   ```
   `run_in_background: true`, `timeout: 600000`. Bulgular ham haliyle alinir, filtrelenmez.
6. **Bulgu degerlendirme**:
   - **<= 3 bulgu veya tek dosya** → ana agent inline duzeltir (workflow kurulumu bulgudan pahali)
   - **daha buyuk** → **fix workflow**: bulgular dosyaya gore gruplanir, her grup bir `agent()`;
     ayni yasak listesi gecerli (agent duzeltir, dogrulamayi yine ana agent yapar)
   - **Mimari ihlal** (guvenlik acigi, yanlis pattern, para icin float, auth'suz uc): DUR,
     `AskUserQuestion` ile kullaniciya bildir (`coding` kurali)
7. Duzeltme sonrasi **2-4 arasi tekrar kosulur** (yesile donmeden commit yok).

---

## 8. Checkpoint commit + push

Birim yesile dondugunde:

```bash
git add <birim kapsamindaki dosyalar>       # `git add -A` / `git add .` YOK
git commit -m "wip(<birim>): <kisa konu>"    # Co-Authored-By satiri eklenir
git push -u origin <worktree-branch>         # ilk seferde -u, sonrakilerde `git push`
```

- Bu **ara commit**tir, teslimat degil — bu yuzden `commit` skill cagrilmaz. Nihai teslimat
  (kalite kapisi + PR + Plane kapama) **Adim 9**'da `commit` skill'in isidir (`before-commit` kurali).
- `--no-verify` yok: pre-commit hook fail olursa duzelt, tekrar dene.
- Push, oturum olse bile isin kaybolmamasini saglar; yarim birim push edilmez (yalniz yesile
  donmus birim).
- Commit atildiktan **hemen sonra** sonraki birimin workflow'u ayni turda baslatilir (Bolum 11) —
  commit sonrasi kullaniciya donup beklemek yasak.

---

## 9. Kapanis

Tum fazlar bitince ana agent:

1. **Kanit uretir** — standart **Adim 7a-7d**: worktree'de bagimlilik kurulumu → unique port +
   arka planda uygulama → testler/screenshot/API ciktilari `$EVID/` altina → **uygulamayi durdur**.
   Gorsel degisiklikte screenshot zorunlu.
2. **Adim 8** — analiz sayfasina B8-B11 eklenir; **B8/B9'da faz kirilimi** islenir: hangi faz hangi
   gorevleri kapsadi, faz sonu review'da ne cikti, ne duzeltildi.
3. **Adim 8.5** — `[SESSION_NAME]` log temizligi (bloklayici).
4. **Adim 9** — `commit` skill (teslimat + Plane kapama).
5. **Adim 10** — arsivle.

---

## 10. Durustluk

- "Workflow bitti" kanit degildir — kanit `git diff` + kosturulan komutun ciktisidir.
- Bir faz kismen bittiyse "bitti" denmez; ne bitti / ne kaldi ayri yazilir.
- Agent'in `assumptions`/`open_questions` alanlari **okunur ve raporlanir** — sessizce yutulmaz;
  is akisini degistiren bir varsayim varsa analiz sayfasina islenir.
- Birim sonu review'i atlanamaz; "kucuk birim" gerekce degildir.

---

## 11. Kesintisiz yurutme — ana agent is bitene kadar durmaz

Akisin en pahali kaybi **olu zaman**: workflow biter, ana agent kisa bir ozet yazip turu kapatir,
kullanici "devam" yazana kadar hicbir sey olmaz. Bu yasaktir.

### Turu kapatmanin izin verilen UC hali
1. **Tum fazlar bitti** — kanit toplama + Adim 8 sohbet kapisina gelindi
2. **Sert durak** — mimari ihlal, kullanici karari gerektiren belirsizlik, iki tur ust uste
   cozulemeyen hata (`AskUserQuestion` ile sorulur)
3. **Kullanici mudahalesi** — kullanici akisi kesti

Bunlarin disinda tur kapatilmaz. "Faz A bitti, devam edeyim mi?" diye **SORMA** — `ExitPlanMode`
onayi zaten alindi, plan onaylandi demek "sonuna kadar yurut" demektir.

### Bildirim geldiginde
- Workflow / arka plan Bash bitis bildirimi geldiginde **ara rapor yazma** — dogrudan sonraki
  adima gec (dogrula → duzelt → commit → sonraki workflow'u baslat), hepsi **ayni turda**
- Kullaniciya bilgi vermek gerekiyorsa yol `faz-durumu.html` guncellemesidir, mesaj degil

### Beklerken bosta durma
Arka planda is varken (build, test, code-review, workflow) ana agent **paralel ilerleyebilecek
isleri o sirada yapar**:
- `faz-durumu.html` guncelle
- sonraki birimin workflow script'ini yaz (hazir beklesin)
- degismis dosyalari oku, review bulgusuna hazirlan

### Bildirim gelmezse (asilma)
Bir isten makul surede haber yoksa (en uzun beklenen adimin ~2 kati) durumu **kendin tara**:
`TaskList` (workflow/agent durumu), `BashOutput` (arka plan komut ciktisi), `git status`.
Asili is varsa `TaskStop` + ayni script'i `scriptPath` + `resumeFromRunId` ile yeniden baslat —
degismeyen `agent()` cagrilari onbellekten doner, bastan kosmaz.

Bir kosulun gerceklesmesini beklemek gerekiyorsa `sleep` **kullanma** (on planda bloklu):
`Bash(run_in_background: true)` + `until <kosul>; do sleep 2; done` deseni ya da `Monitor` kullan —
kosul saglaninca bildirim gelir, ana agent uyanir.
