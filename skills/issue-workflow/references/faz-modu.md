# Faz Modu — Sef + Yonetici + Ekip + Dogrulayici

`issue-workflow` Adim 4.5'te faz modu secildiyse bu dosya gecerlidir. Standart akisin **Adim 5 ve
Adim 7'si** burada tarif edilen 5F/7F ile degistirilir; diger adimlar (1, 2, 3, 4, 6, 8, 8.5, 9, 10)
aynen kalir.

**Ozet:** ana oturum (sef) kod yazmaz — fazlari acar/kapar, is paketi (WP) brief'i yazar, yonetici
agent'lari baslatir, bagimsiz dogrulayici agent'larla PASS/FAIL alir, merge eder, durum dosyalarini
gunceller. Kullaniciya yalniz **sert duraklarda** gidilir.

---

## 1. Roller

| Rol | Kim | Sorumluluk | Yasak |
|---|---|---|---|
| **Sef** | Ana oturum | Faz acar/kapatir, brief yazar, verdict okur, merge eder, durum dosyalarini gunceller, analiz sayfasini besler | Kod yazmaz; kendi isini kendi dogrulamaz; gereksiz soru sormaz |
| **Yonetici** (WP sahibi) | 1 agent / is paketi | Kendi worktree'sini acar, kendi ekibini kurar, isi bitirir, kendi branch'ine commit eder, kanit uretir | Baska WP'nin dosyasina dokunmaz, merge etmez, push/PR yapmaz, `--force`/`--no-verify`/`git stash` yok |
| **Ekip** | Yoneticinin subagent'lari | Mekanik uygulama, arama, test yazimi | Kapsam disina cikmaz |
| **Dogrulayici** | Sefin actigi ayri agent | WP ciktisini **kanitla** dogrular, PASS/FAIL doner | Kod degistirmez, duzeltme yapmaz |

**Neden ayri dogrulayici:** isi yapan taraf kendi isini onaylayamaz. Yonetici "bitti" der,
dogrulayici bagimsiz olarak kanit uretir.

> **Adim 2 ve Adim 4 sub-agent yasagi faz modunda da gecerlidir** — kaynak toplama ve kok-neden
> analizi her zaman ana ajanda kalir. Delege edilen yalniz **uygulama** (Adim 7) isidir.

---

## 2. Adim 5F — Faz/WP plani + entegrasyon worktree'si

### 5F.a Entegrasyon worktree'si
Sef, standart Adim 5'teki gibi `worktree` skill ile worktree'ye girer (`EnterWorktree({ name: <isim> })`).
Bu worktree **entegrasyon dali**dir; WP branch'leri buradan dallanir, merge buraya yapilir.

Ana repo yolunu bir kez sapta ve brief'lerde kullan (sefin cwd'si artik worktree):

```bash
MAIN_REPO=$(git rev-parse --path-format=absolute --git-common-dir | sed 's#/\.git$##')
INT_BRANCH=$(git rev-parse --abbrev-ref HEAD)     # orn worktree-fix-proj-123
```

`SESSION_NAME` = `<isim>` (standart Adim 5 kurali; loglama/temizlik anahtari degismez).

### 5F.b WP ayristirma kurallari
B4 yol haritasi WP'lere bolunur. Her WP:

- **Tek sahipli dosya kumesi** — iki WP ayni dosyayi yazmaz. Yazmak zorundaysa WP bolunmez,
  **sirali faza** tasinir
- **Kendi basina anlamli** — merge edildiginde entegrasyon dali derlenir/calisir durumda kalir
- **Olculebilir cikis olcutu** — "derleniyor", "su test gecti", "su uc su yaniti verdi"
- **Sirali baglilik varsa ayri faz** — A'nin ciktisi B'nin girdisiyse ayni fazda olmaz

Faz icindeki WP'ler **birbirinden bagimsiz**dir ve paralel kosar. Esszamanli yonetici tavani
**K = 3** (sef uygular; asan WP'ler kuyrukta bekler). Cok kucuk WP'lerde K yukseltilebilir,
gerekce `kararlar.md`'ye yazilir.

### 5F.c Plan icerigi
`EnterPlanMode` icinde yazilan plan su tabloyu icerir ve `ExitPlanMode` ile onaylanir
(**tek onay noktasi budur** — faz gecislerinde tekrar sorulmaz):

| Faz | WP | Kapsam | Yazabilecegi yollar | Cikis olcutu |
|---|---|---|---|---|
| 1 | WP-A | ... | `app/x/**`, `tests/x/**` | ... |

Ayrica planda: cok-sahipli dosyalarin sahibi, migration/numara bloklari (WP basina aralik),
faz sirasi ve gerekcesi.

### 5F.d Durum dosyalari
Sef uc dosya tutar — **repo disi**, kanit klasoruyle ayni yerde
(`~/.pa-render/active/<isim>/`). Oturum olurse yeni oturum buradan devam eder:

| Dosya | Icerik |
|---|---|
| `faz-durumu.md` | Faz no; her WP icin durum (`bekliyor` / `kosuyor` / `dogrulaniyor` / `duzeltme-turu-N` / `hazir` / `bloke`), agent adi, branch, merge SHA |
| `kararlar.md` | Sorulmadan verilen her karar: karar, gerekce, alternatif, geri donulebilirlik |
| `borc.md` | Merge edildi ama `minor` ihlal tasiyan isler — sonda toplu temizlik listesi |

Her faz gecisinde ve her sert durakta guncellenir. Plan onaylanir onaylanmaz ilk hallerini yaz.

---

## 3. Adim 7F — Faz dongusu

```
[Sef] faz N'in WP listesini al (esszamanli tavan K)
   |
   +-> her WP icin brief yaz -> yonetici agent'i arka planda baslat (Agent, name: wp-<kod>)
   |
   +-> (bitis bildirimi geldikce) o WP icin dogrulayici agent baslat (name: verify-<kod>)
   |
   +-> PASS -> WP'yi hazir isaretle, entegrasyon dalina merge et
   |   FAIL -> ayni yoneticiye SendMessage ile bulgulari ilet (tur sayaci +1)
   |           tur >= 2 ve hala FAIL -> SERT DURAK
   |
   +-> fazin tum WP'leri hazir mi?
       evet -> faz-kapanis dogrulamasi -> analiz sayfasi + durum dosyalarini guncelle -> faz N+1'i ac (SORMADAN)
       hayir -> bekle (watchdog)
```

### Agent baslatma
```
Agent({
  name: "wp-<kod>",
  subagent_type: "general-purpose",
  model: "opus",              // acik yazilir; bkz. Bolum 7
  prompt: <yonetici brief'i>
})
```
Arka planda kosar; bitis bildirimi geldiginde sef uyanir. `name` verilmesi sarttir — duzeltme
turu `SendMessage({ to: "wp-<kod>" })` ile ayni agent'a, **baglami korunarak** gider.

### Merge (PR'siz, lokal)
Dogrulayici PASS verince sef entegrasyon worktree'sinde:

```bash
git merge --no-ff wp-<kod> -m "merge: WP-<kod> — <kisa konu>"
git worktree remove "$MAIN_REPO/.claude/worktrees/wp-<kod>"   # branch birakilir (iz)
```

- **Conflict cikarsa sef cozmez** — WP'yi `bloke` isaretler, ilgili yoneticiye `SendMessage` ile
  "entegrasyon dalini rebase et, cakismayi coz, tekrar rapor et" der
- Her merge sonrasi **acik WP'lere** `SendMessage` ile rebase talimati gider (entegrasyon dali ilerledi)
- Push/PR yok: nihai teslimat Adim 9'da `commit` skill'in isidir

### Faz-kapanis dogrulamasi (ZORUNLU)
Fazin tum WP'leri merge edildikten sonra **ayri bir dogrulayici agent** entegrasyon dalinda
butunlesik duman testi kosar (build + test + kritik akis). Sef bu testi kendisi kosup "gecti"
diyemez (Bolum 8). FAIL ise: hangi WP'nin yol actigi belirlenir, o yoneticiye duzeltme turu acilir.

### Watchdog
Bildirim gelmeyen/asilan agent icin sef `TaskList` ile durum tarar. Kural: en uzun beklenen adimin
~2 kati gecikme (20-30 dk) makul; altinda taramak bosa tur. Asili gorunen agent'a `SendMessage` ile
durum sorulur; yanit gelmezse `TaskStop` + ayni brief'le yeniden baslatilir (tur sayaci artmaz,
`kararlar.md`'ye yazilir).

---

## 4. Yonetici brief sablonu

Her yonetici **yazili, sinirlari cizilmis** gorev kartiyla baslar. Eksik kart = kapsam kaymasi.

```
Sen WP-<kod> sahibisin: <alan adi>.

HEDEF
<tek paragraf: ne bitmis olacak>

KAPSAM (bunlar ve yalniz bunlar)
- <madde>

KAPSAM DISI
- <acikca yapilmayacaklar>

REPO / BRANCH
- Ana repo: <MAIN_REPO>   Entegrasyon dali: <INT_BRANCH>
- Worktree'ni SOYLE ac:
  git -C <MAIN_REPO> worktree add <MAIN_REPO>/.claude/worktrees/wp-<kod> -b wp-<kod> <INT_BRANCH>
  cd <MAIN_REPO>/.claude/worktrees/wp-<kod>
- Harness'in isolation:worktree'sini KULLANMA (yanlis tabandan dallanir).

DOSYA SINIRI
- Yazabilecegin yollar: <liste>
- DOKUNMA (baska WP'nin): <liste>
- Migration/numara blogun: <aralik>

EKIBIN
- Subagent kullanabilirsin; her cagrida model ACIKCA yaz: salt-okunur arama/envanter -> sonnet,
  yazan/karar veren her is -> opus. haiku kullanma.
- Kendi isini kendin review etme; dogrulama ayri bir agent tarafindan yapilacak.

CALISMA KURALLARI
- Proje anayasasi gecerlidir: CLAUDE.md + CLAUDE.local.md + ~/.claude/rules/ (coding kurali:
  hata wrap, TODO yorumu, workaround yok; Turkce iletisim / Ingilizce kod yorumu).
- Gelistirme sirasinda kritik akis noktalarina [<SESSION_NAME>] prefix'li detayli log ekle
  (dilin logger'i varsa). Temizligi sef Adim 8.5'te yapacak.
- Testini kendi worktree'nde, unique port ile ARKA PLANDA kosur; bitince process'i DURDUR
  (orphan port/process birakma).
- Kanitlarini <EVID>/wp-<kod>/ altina yaz (screenshot / test ciktisi / API yaniti / diff).
  Gorsel degisiklikte screenshot ZORUNLU (playwright-cli).

CIKIS OLCUTU
- <olculebilir maddeler: derleniyor, su test gecti, su uc su yaniti verdi>
- Bitince kendi branch'ine commit at (ara commit; teslimat degil, bu yuzden commit skill
  cagirmiyorsun). Pre-commit hook'lari calissin.

YASAKLAR
- MERGE ETME, PUSH ETME, PR ACMA — merge sefin isi, teslimat en sonda commit skill'in
- main'e dokunma, v* tag yok, deploy tetikleyen hicbir sey yok, prod DB'ye migration yok
- git stash yok (paylasilan stack), --no-verify yok, --force yok
- Dosya sinirin disina yazma; ihtiyacin varsa raporunda open_questions'a yaz

RAPOR (son mesajin SADECE bu JSON olsun)
{ "wp": "...", "status": "done|blocked",
  "branch": "wp-<kod>", "commits": ["sha — konu"],
  "files_changed": ["..."],
  "exit_criteria": [{"item": "...", "met": true, "evidence": "<komut + cikti ozeti>"}],
  "evidence_files": ["<EVID>/wp-<kod>/..."],
  "assumptions": ["..."], "open_questions": ["..."], "notes": "..." }
```

---

## 5. Dogrulayici brief sablonu

```
Sen WP-<kod> icin BAGIMSIZ dogrulayicisin. Kod DEGISTIRME, duzeltme YAPMA, commit ATMA.

Dogrulanacak iddia: <yoneticinin JSON raporu>
Repo: <MAIN_REPO>   Branch: wp-<kod>   Entegrasyon dali: <INT_BRANCH>

YAP
1. Diff'i oku (git -C <MAIN_REPO> diff <INT_BRANCH>...wp-<kod>) — iddia edilen degisiklikler
   gercekten var mi?
2. Her cikis olcutunu KENDIN calistirarak sina (build, test, curl, migration status...).
   Yoneticinin ciktisina guvenme, komutu tekrar kostur.
3. Kapsam ihlali ara: dosya siniri disina cikilmis mi, yasakli komut kullanilmis mi
   (merge/push/PR/tag/--force/--no-verify/stash).
4. Proje anayasasina aykirilik ara: CLAUDE.md, CLAUDE.local.md, ~/.claude/rules/.
5. Sessiz gerileme ara: mevcut davranisi bozan bir degisiklik var mi.
6. Kanit dosyalarini kontrol et: iddia edilen screenshot/test ciktisi gercekten var mi, neyi
   ispatliyor; canli credential/JWT sizmis mi.

VERDICT (son mesajin SADECE bu JSON olsun)
{ "wp": "...", "verdict": "PASS|FAIL",
  "checks": [{"criterion":"...","result":"pass|fail","evidence":"<komut + GERCEK cikti>"}],
  "violations": [{"severity":"critical|major|minor","file":"...","line":0,"issue":"...","fix":"..."}],
  "regressions": ["..."], "summary": "..." }

Kural: kanitsiz PASS yok. Bir olcutu kosturamadiysan "pass" yazma — durumu acikca yaz ve
verdict'i FAIL ver.
```

---

## 6. Kapi kurallari (sefin karar tablosu)

| Verdict | Sefin aksiyonu |
|---|---|
| PASS, ihlal yok | Merge -> WP hazir |
| PASS, yalniz `minor` ihlal | Merge et, ihlalleri `borc.md`'ye yaz |
| PASS ama kanit tutarsiz (test gecti deniyor, cikti yok) | **FAIL sayilir** — duzeltme turu |
| FAIL, tur 1 | Ayni yoneticiye `SendMessage` ile bulgulari gonder, duzeltme iste |
| FAIL, tur 2 | **SERT DURAK** |
| `critical` ihlal (mimari) | **SERT DURAK** — tur sayisina bakma |

**Sert duraklar — kullaniciya gidilen tek durumlar** (her zaman `AskUserQuestion`, `ask-first` kurali):

1. Canliya alma adimlari: deploy, surum tag'i, prod migration, deploy bayragi acma
2. Ayni WP'de iki tur ust uste FAIL
3. Mimari ihlal (proje anayasasina aykiri: para icin float, ham SQL enjeksiyonu, auth'suz uc,
   guvenlik acigi...) — `coding` kuralinin "mimari ihlal gorursen DUR" maddesiyle ayni

Bunlarin disinda sef **durmaz, sormaz**: belirsizlik cikarsa varsayimla ilerler ve gerekcesini
`kararlar.md`'ye yazar. Faz gecisleri kullaniciya sorulmaz.

---

## 7. Cakisma protokolu

1. Her WP **kendi worktree + kendi branch**. Ayni worktree'de iki agent calismaz.
2. **Cok-sahipli dosyalar** planda listelenir; her birinin tek sahibi vardir. Sahibi olmayan
   dokunmaz, ihtiyacini raporuna yazar, sef siraya koyar.
3. Migration/numara/sira gerektiren kaynaklar **sef tarafindan blok halinde** dagitilir.
4. Merge sirasini sef belirler; her merge sonrasi acik WP'ler entegrasyon dalini rebase eder
   (sef `SendMessage` ile soyler).
5. Bir dosya iki WP'de birden degismek zorundaysa: WP'yi bolmek yerine **sirali faza** tasi.

---

## 8. Model politikasi

**Yazan her el `opus`.** Dosyayi degistiren, kod/sema/test ureten, karar veren hicbir agent daha
kucuk modelle kosmaz — ikinci duzeltme turu, model tasarrufundan pahalidir.

| Is | Model |
|---|---|
| Yonetici agent | `opus` |
| Ekip: kod, sema, migration, UI, test yazimi, refactor, dokumantasyon | `opus` |
| Dogrulayici + faz-kapanis dogrulayicisi | `opus` |
| **Salt-okunur**: dosya/sembol arama, envanter, log tarama, probe | `sonnet` |
| `haiku` | Kullanilmaz |

- Her `Agent` cagrisinda `model` **acikca** yazilir; varsayilana birakilmaz (`token-efficiency` kurali).
- Hem okuyup hem yazan agent `opus`'tur — "cogunlukla okuma yapiyor" gerekcesiyle dusurulmez.
- ⛔ **Fable Model Baraji** (SKILL.md Adim 5): fable oturumunda hicbir agent/workflow fable ile
  kosmaz, ust sinir `opus`. Bu tablo zaten o barajla uyumludur.
- **Tek tur disiplini**: yonetici isi "yeterince iyi" birakip dogrulayicinin bulmasini bekleyemez;
  cikis olcutlerini kendi kosturup yesile getirdikten sonra rapor eder.

---

## 9. Sefin durustluk yukumlulugu

- Dogrulamayi agent yaptiysa rapor **"dogrulayici agent onayladi"** diye yazilir, "ben dogruladim"
  diye degil.
- Dogrulayicinin kanit olarak verdigi komut ciktisi tutarsizsa verdict **FAIL** sayilir.
- Bir WP kismen bittiyse "bitti" denmez; ne bitti / ne kaldi ayri ayri yazilir.
- Agent'in "yaptim" demesi kanit degildir — kanit komut ciktisidir (`workflow` kurali: subagent
  ciktisi dogrulanana kadar guvenilmezdir).

---

## 10. Analiz sayfasi ve standart akisla birlesme

- Analiz sayfasina (`~/.pa-render/active/<isim>/index.html`) **BF — Faz Durumu** bolumu eklenir:
  faz/WP tablosu, her WP'nin durumu, verdict ozeti, merge SHA'lari. Her faz kapanisinda `Edit`
  ile guncellenir. B1..B11 numaralari bozulmaz.
- Son faz kapaninca standart akisa donulur: **Adim 8** (B8-B11; kanitlar WP klasorlerinden
  toplanir) -> **Adim 8.5** (`[SESSION_NAME]` log temizligi entegrasyon dalinda, bloklayici) ->
  **Adim 9** (`commit` skill) -> **Adim 10** (arsivle).
- Adim 8.5 temizligi sefin isidir ve **merge edilmis tum WP'leri kapsar**: entegrasyon
  worktree'sinde `grep -rn "\[<SESSION_NAME>\]" .` bos donene kadar.
- `borc.md`'de kalan `minor` ihlaller Adim 8'de **B10/B8'e** islenir — sessizce yutulmaz.
