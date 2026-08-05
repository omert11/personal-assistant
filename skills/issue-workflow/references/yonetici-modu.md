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
4. **Her faz bir workflow.** Faz icindeki gorevler o script'in `agent()` cagrilaridir.
5. **Faz sonunda dogrulama + checkpoint commit + push.** Yarim faz bir sonrakine tasinmaz.
6. **Duzeltme ucuz tarafta yapilir**: kucuk bulgu ana agentta, buyuk bulgu seti fix workflow'da.

---

## 3. Adim 7Y — Akis

```
[Ana agent] plandaki fazlari sirala (Adim 5'te belirlendi)
   |
   +-> Faz N (ve ayrik ise N+1) icin workflow script yaz -> Workflow baslat
   |
   +-> bitis bildirimi -> ciktilari DOGRULA (dosyalar gercekten degisti mi)
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
   +-> sonraki faz
   |
   +-> tum fazlar bitti -> kanit toplama (Adim 7a-7d, ana agent) -> Adim 8
```

### Durum takibi — uc katman

| Katman | Nerede | Ne zaman |
|---|---|---|
| **Oturum ici canli** | `TaskCreate`/`TaskUpdate` — her faz bir gorev | Faz basi `in_progress`, commit sonrasi `completed` |
| **Ekranda gorunur** | `~/.pa-render/active/<isim>/faz-durumu.html` (PA Render **ek dosya**) | Faz basi + faz sonu (asagi) |
| **Kalici kayit** | Checkpoint commit + push (`wip(<faz>): …`) | Faz yesile donunce |

Faz ici ilerleme ayrica `/workflows` agacinda canli gorunur; workflow bitince bildirim gelir.

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

**Guncelleme anlari** (her biri tek `Edit`):
1. Faz workflow'u baslarken → `kosuyor`
2. Workflow bitip dogrulama baslarken → `dogrulaniyor`; review bulgusu cikarsa `duzeltme` + bulgu ozeti
3. Checkpoint commit sonrasi → `tamam` + commit SHA'si

Oturum olurse yeni oturum bu dosyadan + `git log`'dan devam eder — plan analiz sayfasinda,
nerede kalindigi burada.

### Ornek sıralama

```
Faz A: G1, G2, G3     Faz B: G4, G5     Faz C: G6, G7, G8     Faz D: G9, G10

1. Faz A workflow + Faz B workflow  (A ve B tamamen ayriksa PARALEL)
2. build + test + lint + code-review
3. gerekiyorsa fix workflow
4. checkpoint commit + push
5. Faz C workflow
6. build + test + lint + code-review
7. fix (gerekirse) -> commit + push
8. ... son faza kadar
9. Kanit toplama -> Adim 8 (analiz sayfasi) -> 8.5 -> 9 (commit skill)
```

---

## 4. Fazlama ve paralellik kurallari

### Faz kurma
- Bir gorevin **ciktisi** baska bir gorevin **girdisiyse** ayni fazda olamaz — sonraki faza gider
- Ayni dosyaya yazan iki gorev ayni fazda **paralel** olamaz: ya tek goreve birlestir ya da
  workflow icinde **ardisik** kostur (`await agent(A)` sonra `await agent(B)`)
- Her gorev icin **yazabilecegi dosya yollari** onceden belirlenir; ortusme yoksa paralel

### Iki fazi paralel kosturma
Iki faz **ancak** su ucu birden sagliyorsa paralel kosar:
1. Dosya kumeleri kesismiyor
2. Hicbiri digerinin ciktisina bagli degil
3. Ikisinin toplam agent sayisi tavani asmiyor (asagi)

### Agent tavani (M1 Pro 8 cekirdek / 16 GB)
| Durum | Tavan |
|---|---|
| Tek workflow kosuyor | **<= 8 agent** |
| Iki workflow paralel | **her biri <= 4 agent** (toplam <= 8) |

Is tavani asiyorsa **daha fazla esszamanli agent acma** — workflow **icinde asamalandir**:
gorevleri `parallel()` bloklarina veya `pipeline()` stage'lerine bol, ardisik kossunlar. Tavan
makinenin sinirindan gelir; asmak swap'e girer ve sirayla kosmaktan yavaslatir (`heavy-build` kurali).

---

## 5. Workflow script sablonu

Her faz icin **inline `script`** ile `Workflow` cagrilir (dosyaya yazma; tool zaten script'i
oturum dizinine kaydeder ve `scriptPath` doner — duzeltme gerekirse o yol kullanilir).

```js
export const meta = {
  name: 'faz-a-<konu>',
  description: '<faz tek cumleyle>',
  phases: [{ title: 'Uygula', detail: '<n> gorev, dosya-ayrik' }],
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

const GOREVLER = [
  { kod: 'G1', brief: `<agent brief'i — Bolum 6>` },
  { kod: 'G2', brief: `...` },
]

phase('Uygula')
const sonuc = await parallel(GOREVLER.map(g => () =>
  agent(g.brief, { label: `uygula:${g.kod}`, phase: 'Uygula', model: 'opus', schema: RAPOR })
))
return { gorevler: sonuc.filter(Boolean) }
```

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

Faz yesile dondugunde:

```bash
git add <faz kapsamindaki dosyalar>      # `git add -A` / `git add .` YOK
git commit -m "wip(<faz>): <kisa konu>"   # Co-Authored-By satiri eklenir
git push -u origin <worktree-branch>      # ilk fazda -u, sonrakilerde `git push`
```

- Bu **ara commit**tir, teslimat degil — bu yuzden `commit` skill cagrilmaz. Nihai teslimat
  (kalite kapisi + PR + Plane kapama) **Adim 9**'da `commit` skill'in isidir (`before-commit` kurali).
- `--no-verify` yok: pre-commit hook fail olursa duzelt, tekrar dene.
- Push, oturum olse bile isin kaybolmamasini saglar; yarim faz push edilmez (yalniz yesile
  donmus faz).

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
- Faz sonu review'i atlanamaz; "kucuk faz" gerekce degildir.
