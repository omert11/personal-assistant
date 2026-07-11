---
name: issue-workflow
description: Issue/ticket/doc/gorsel kaynagini interaktif HTML analiz akisiyla analiz eder, cozer, kanitlar.
when_to_use: Trigger — "su ticket'i coz", "issue-workflow ile bak", "bu hatayi worktree'de coz", "ticket analiz et ve duzelt", "su dokumandaki sorunu hallet", "/issue-workflow <ref|metin>". Bir issue/ticket/dokuman/gorsel/mesaj kaynagi verilip uctan uca (kaynak → HTML analiz → plan → cozum → kanit → commit) cozulmesi istendiginde. Tek seferlik kucuk duzeltmeler icin gerekmez; kok-neden analizi + izolasyon + kanit gerektiren islerde.
argument-hint: <ticket-ref | serbest-metin | dosya-yolu>
disable-model-invocation: false
effort: max
allowed-tools: Bash, BashOutput, KillShell, Read, Write, Edit, Grep, Glob, AskUserQuestion, Task, WebFetch, Workflow, EnterWorktree, ExitWorktree, EnterPlanMode, ExitPlanMode, Skill
---

# Issue Workflow — Kaynak → HTML Analiz → Plan → Cozum → Kanit → Commit

Verilen bir **kaynagi** (Plane issue, serbest metin, dokuman, gorsel, mail, log) uctan uca cozer.
Akisin omurgasi **tek buyuyen bir lokal HTML analiz sayfasidir**: analiz gruplar halinde yazilir,
sayfa **default browser'da `open` ile acilir** (Artifact tool ile claude.ai'ye YUKLENMEZ — yukleme
akisi yok, dosya lokalde kalir), her grupta kullaniciyla sohbet edilir, kullanici onay verene kadar
o adimda kalinir. Cozum izole worktree'de uygulanir, kanitlarla teyit edilir, teslimat `commit`
skill'e devredilir.

> **Bu skill yalniz isleri SIRALAR — agir mantigi ayri skill'lere delege eder.**
> Worktree → `worktree` skill. Teslimat → `commit` skill. Log → `diji-logs` skill.
> Plane → `plane-cli` skill. Sayfa tasarimi → `artifact-design` skill. DRY.

---

## Durus — Agent Uzmandir

Kullanici **istek/talep** bildirir; agent **mimar/muhendis/ureticidir** — en dogru yolu agent belirler.
Kullanicinin istegini sorgusuz uygulamaya zorlanma; istegin arkasindaki ihtiyaci coz ve en dogru
cozumu tasarla. Bu durus akisin her adiminda gecerlidir:

- **En estetik yolu arastir** — ilk calisan cozumde durma; "daha zarif/basit yol var mi?" (coding kurali)
- **Global standartlara bak** — benzer sorunlar sektorde/framework'te nasil cozuluyor; yerlesik pattern varsa onu tercih et
- **Yapisal imkansizliklari durust degerlendir** — mimari olarak olmayacak seyi "olur" deme; kisiti acikca raporla
- **Ek kazanim gordugunde raporla** — cozum sirasinda fark edilen iyilestirme/firsat gizlenmez, artifact'e islenir
- **Kolay olani degil DOGRU olani sec** — kolay cozum ileride daha fazla is cikarir; sorun simdi, en dogru sekilde cozulur

> ## ⚠ Sub-agent YASAGI — Adim 2 ve Adim 4
> **Kaynak analizi (Adim 2) ve durum/yol-haritasi analizi (Adim 4) ASLA sub-agent'a yaptirilmaz.**
> Bulgular ve analiz bu isin kritik cekirdegidir; sub-agent izole context'te calisir ve ana
> baglamdan kopar — yanlis/eksik analiz uretir. Bu iki adimi **her zaman ana ajan kendi
> context'inde, `effort: max` ile** yapar. (Istisna: `obsidian-searcher` *on aramasi* — analiz
> yapmaz, gecmis notu context'e GETIRIR; ve `diji-logs`/`worktree`/`commit`/`plane-cli` gibi
> **skill delegasyonlari** — bunlar sub-agent degil, ayri skill cagrilaridir.)

---

## Analiz Sayfasi (HTML) Kurallari (Adim 3, 4, 8'de gecerli)

Kullanici gorsel grafik/akis/karsilastirma ile cok daha hizli anlar — **sayfa gorsel-agir,
metin kisa-net** olmalidir:

- **LOKAL dosya, browser'da ac — Artifact tool KULLANILMAZ**: sayfa claude.ai'ye yuklenmez.
  Dosya `/tmp/<isim>/analiz.html` (isim Adim 5'teki kurala gore erken turetilir), ilk yazimdan
  sonra `open "/tmp/<isim>/analiz.html"` ile default browser'da acilir
- **Ilk yazimdan ONCE `artifact-design` skill'ini yukle** — efor kalibrasyonu ve tasarim
  temelleri oradan gelir (tam HTML iskeleti gerekir: `<!doctype html>` + `<head>` + `<body>`,
  CSS inline; lokal dosyada Artifact CSP kisiti yok ama sayfa yine self-contained tutulur)
- **TEK dosya, buyuyerek**: her grupta yeni bolumler ayni dosyaya EKLENIR (`Edit`). Grup basina
  yeni dosya ACILMAZ. Guncelleme sonrasi tekrar `open` cagir — browser ayni dosyayi tazeler
- **Gorsel yogun**: akis diyagramlari (inline SVG/CSS), once/sonra karsilastirmalari, durum
  rozetleri, mimari semalar, tablolar. Uzun paragraf yerine sema + kisa madde
- **Kanit gorselleri** (Adim 8): sayfa `$EVID` icinde oldugu icin screenshot'lar goreli yolla
  gosterilir (`<img src="screenshot-after.png">`) — `data:` URI gomme gereksiz
- **Bolum numaralari korunur** (B1..B11) — kullanici bolume numarayla atif yapabilir
- Kullanici duzenleme/istek bildirdiginde: dosyayi `Edit` ile guncelle → tekrar `open` →
  degisikligi tek cumleyle bildir

**Sohbet kapisi deseni** (Adim 3, 4, 8 sonunda): sayfa acildiktan sonra `AskUserQuestion`
ile sor (header: "Akis"):
- options: `["Akisa devam et", "Duzenleme/istek var"]` (Adim 8'de: `["Commit skill calistir", "Duzenleme/istek var", "Iptal"]`)
- "Duzenleme/istek var" → istegi al, artifact'i guncelle, TEKRAR sor. Kullanici devam diyene
  kadar bu adimda kalinir — sohbete devam edilir, akis ilerletilmez.

---

## Adim 1 — CLAUDE.local.md "## Issue Workflow" alanini oku (ILK IS)

```bash
grep -n "## Issue Workflow" CLAUDE.local.md 2>/dev/null
```

Varsa **tamamini oku ve uygula** — proje-ozel talimatlar buradadir:
- **Uygulama baslatma komutu** (orn `uv run manage.py runserver`, `npm run dev`, `go run .`)
- **Test komutlari** (orn `pytest`, `npm test`, ozel e2e komutu)
- **Port stratejisi** / ortam degiskenleri
- **Bagimlilik kurulum** adimlari (worktree'de calistirilacak)
- **Kullanici-ozel akis notlari**

> Bolum **yoksa** zorlama — genel akisla devam et. Is sirasinda proje-ozel bir ihtiyac dogarsa
> `CLAUDE.local.md`'ye bu bolumu ekle/guncelle (sablon Ek'te) ki sonraki calismalar otomatik okusun.

---

## Adim 2 — Kaynak toplama (ATLANAMAZ, ANA AJAN)

Kullanicinin verdigi her kaynagi **tek tek, tam detayli** incele — gorseller dahil. Hicbirini
atlama, ozetle gecme. **Sub-agent'a verilmez.**

| Kaynak tipi | Nasil al |
|---|---|
| **Plane issue** (`PROJ-123`, `61618`) | `plane-cli` skill → `issue get-id` (UUID coz) + `issue get` + `comment list` (tum yazismalar) + ekler. Ekli gorsel/dosya varsa indir ve oku |
| **Serbest metin / mesaj** | Dogrudan oku, talebi/sikayeti madde madde cikar |
| **Gorsel** (ekran goruntusu, hata diyalogu) | `Read` ile gor — hata metni, kod, ekran durumu, URL'leri cikar. TR hata mesaji ise orijinal msgid'i `grep ... locale/*/LC_MESSAGES/*.po` ile bul |
| **Dokuman** (PDF/Word/HTML/dosya) | `markitdown <dosya> > /tmp/src.md` ile markdown'a cevir, sonra oku. URL ise `WebFetch` |
| **Log / hata ciktisi** | VictoriaLogs erisimi olan diji projesiyse `diji-logs` skill'e delege (LogsQL arama); kapsamli tarama icin `log-triage`; degilse Grep ile log dosyalarini tara |

> Obsidian vault tanimliysa `obsidian-searcher` agent'ini `run_in_background: true` ile cagir
> (QUERY: sorunun ozeti) — onceki oturum bu sorunu cozmus olabilir.

Cikti: anahtar veriler (ref, hata kodu, kullanici, tarih, modul/dosya/endpoint) context'te hazir —
Adim 3 artifact'inin hammaddesi.

---

## Adim 3 — Analiz Sayfasi Grup 1 (B1–B3) + sohbet kapisi

`artifact-design` skill'ini yukle, sonra sayfanin ilk uc bolumunu yaz ve `open` ile browser'da ac:

- **B1 — Suanki Durum**: sistemin bugunku davranisi — akis semasi, ilgili modul haritasi, varsa hata/ekran gorseli
- **B2 — Ne Isteniyor**: talep — somut, madde madde; once/sonra karsilastirma gorseli uygunsa
- **B3 — Neden Isteniyor**: ihtiyacin koku — is degeri, etkilenen kullanici/akis, aciliyet

Ac → **sohbet kapisi** (yukaridaki desen). Kullanici "Akisa devam et" diyene kadar bu adimda
kal: duzenleme/istek al, sayfayi guncelle, tekrar sor. Kaynak anlayisinda yanlislik varsa
burada duzeltilir — sonraki adimlar bu uc bolumun uzerine kurulur.

---

## Adim 4 — Analiz Sayfasi Grup 2 (B4–B7): Tam durum + yol haritasi (ULTRATHINK, ANA AJAN)

> Bu adimda **derin dusun** — `effort: max` aktif. Yuzeysel ilk hipotezde durma; kodu/logu/sorunu
> gerekli gordugun kadar incele (`Grep`/`Glob`/`Read`/`Bash`). Kok nedeni belirle — semptomu degil.
> Global standartlari ve en estetik cozum yolunu arastir (Durus bolumu). **Sub-agent kullanma.**

Analiz bitince ayni HTML dosyasina dort bolum EKLE ve tekrar `open` ile ac:

- **B4 — Ne Hazir / Ne Yapilacak / Nasil Yapilacak**: mevcut altyapida hazir olanlar; yapilacak
  isler; her isin nasil yapilacagi — yol haritasi semasi/asama diyagrami ile
- **B5 — Oneriler / Iyilestirmeler**: talebin otesinde gorulen iyilestirme firsatlari (uzman gozu)
- **B6 — Acik Konular**: kararlastirilmasi gereken her sey — secenekleriyle
- **B7 — Riskler / Durust Avantajlar / Durust Dezavantajlar / Zayif Yonler**: risk matrisi;
  cozumun artilari-eksileri SUSLENMEDEN; yapisal imkansizlik varsa acikca

**Acik konularin TAMAMI bu adimda kapatilir**: her B6 maddesi icin `AskUserQuestion` ile karar al
(secenekler + onerilen isaretli), karari sayfaya isle. Riskler kullaniciya durustce bildirilir.

Sonra **sohbet kapisi** — kullanici "Akisa devam et" diyene kadar bu adimda kal.

---

## Adim 5 — Worktree ac + Plan modu

Kaynaktan **anlamli, kebab-case** isim turet:
- Plane issue → `fix-<issue-ident>` (orn `fix-proj-123`)
- Bug → `fix-<kisa-konu>`, Feature → `feat-<kisa-konu>`

`worktree` skill'inin `new <isim>` akisini kullan (`Skill(worktree, "new <isim>")` veya dogrudan
`EnterWorktree({ name })`). Session cwd worktree'ye gecer; `/tmp/<isim>/` kanit klasorunun yeridir.

Sonra **plan moduna gir** ve tam plani yaz:

```
EnterPlanMode()
```

Plan **tum isleri kapsamali** — B4-B7'de kararlastirilanlarin somut uygulamasi:
- Yapilacak degisiklikler (hangi dosyada ne — madde madde)
- Kapatilan acik konularin kararlari
- Yan etki / risk ve nasil dogrulanacagi
- **Paralelize edilebilir isler**: birbirinden bagimsiz is paketleri varsa `Workflow` ile paralel
  uygulanacagini planda belirt (token-efficiency kurali: her `agent()` cagrisinda acik `model`,
  fable oturumunda ust sinir `opus`; dosya cakismasi varsa `isolation: 'worktree'`)

> ⛔ **Fable Model Baraji (MUTLAK, esnetilemez):** Ana oturum modeli Fable ise hicbir workflow
> `agent()` cagrisi veya subagent fable ile calistirilmaz — ust sinir `opus`. Kendi yazdigin
> script'lerde her `agent()` cagrisina acik `model` yaz. **Hazir/named workflow'lar
> (`Workflow({name: ...})`, built-in code-review dahil) fable oturumunda dogrudan launch
> EDILMEZ** — once script kopyasina model override yaz, `scriptPath` ile calistir; kopya
> mumkun degilse launch etme, kullaniciya `AskUserQuestion` ile sor. Ayni baraj bu akisin
> cagirdigi `commit` skill'inin code-review adimi icin de gecerlidir (kanitlanmis ihlal
> maliyeti: 2026-07-10, 20 agent x fable ~ 2M token, harcama limiti asimi).

```
ExitPlanMode()
```

> `ExitPlanMode` onayi tek onay noktasidir — ayrica "onayliyor musun?" diye SORMA.

---

## Adim 6 — Plane issue'yu ISLEME AL (kaynak Plane issue ise; OTOMATIK, plan onayi sonrasi)

Plan onaylandi = is gercekten basliyor → issue simdi isleme alinir. Kaynak Plane issue **degilse**
veya Plane proje tanimli degilse bu adim atlanir.

> CLI sozdizimi `plane-cli` skill'inden gelir. **Onay sorma — otomatik uygula**, sonra tek satir
> bildir (orn "PROJ-123 isleme alindi: started + self atandi + start_date=bugun").

Sirayla (`--json` ile):
1. **Issue'nun mevcut halini al** (`issue get`) — assignee, `start_date`, state group
2. **Yalnizca `backlog`/`unstarted` ise `started`'a cek** (`state list` → started UUID → `issue update --state`). Zaten started/completed/cancelled ise DOKUNMA
3. **Assignee bossa self ata** — `member me` → `issue assignee --add` (incremental; REPLACE yapan `update --assignees` KULLANMA). Dolu ise dokunma
4. **`start_date` bossa bugunu ata** — `issue update --start-date $(date +%Y-%m-%d)`. Dolu ise dokunma

> **Idempotent**: tekrar calistirmada dolu alan/atama bozulmaz. Label/priority/target-date bu
> adimda set EDILMEZ — onlar `commit` skill'inin kapama adiminin sorumlulugudur.

---

## Adim 7 — Uygula + Test + Kanit

Plani uygula (`coding` kurallari: hata wrap, TODO yorumlari, workaround yok). Planda paralel is
paketleri tanimlandiysa `Workflow` ile dagit — cikti dogrulamasi sende (`workflow` kurali;
fable oturumunda Adim 5'teki **Fable Model Baraji** aynen gecerli: her `agent()` acik model,
named workflow'a dogrudan launch yok).

Sonra cozumu **calisan uygulamada** test et ve kanitla:

```bash
EVID=/tmp/<isim>
mkdir -p "$EVID"
```

### 7a. Test ortamini worktree'de hazirla
Worktree izole kopyadir — uygulamayi burada kur (ana checkout'a dokunma). Komutlar Adim 1'in
"## Issue Workflow" alanindan; yoksa proje tipinden cikar (Python: `uv venv` + requirements,
Node: `npm install`, Go: `go build ./...`).

### 7b. Unique port ile ARKA PLANDA calistir
```bash
PORT=$(python3 -c "import socket;s=socket.socket();s.bind(('',0));print(s.getsockname()[1]);s.close()")
echo "$PORT" > "$EVID/.port"
# run_in_background: true ile baslat — orn:
#   Django: .venv/bin/python manage.py runserver 127.0.0.1:$PORT 2>&1 | tee $EVID/server.log
#   Node:   PORT=$PORT npm run dev 2>&1 | tee $EVID/server.log
```
Bound port'u bekle (`curl --retry` / port-check), hazir olunca testlere gec.

### 7c. Testler + kanit dosyalari
| Sorun tipi | Kanit araci | Cikti |
|---|---|---|
| **Gorsel / UI / akis** | `playwright-cli` skill (`PORT`'a baglan) | `$EVID/screenshot-*.png` (before/after) |
| API / backend endpoint | `curl`/`Bash` (`localhost:$PORT`) | `$EVID/api-before.json`, `$EVID/api-after.json` |
| Mantik / fonksiyon | test (`pytest`/`npm test`) | `$EVID/test-output.txt` (PASS) |
| Veri / DB / log | shell sorgu | `$EVID/query-result.txt` |
| Her durum | before/after diff | `$EVID/diff.txt` (`git diff > ...`) |

> **Gorsel degisiklikte GORSEL KANIT ZORUNLU** — `playwright-cli` ile screenshot, mumkunse
> before/after. Gorsel kanit olmadan gorsel cozum "kanitlanmis" sayilmaz.

### 7d. Arka plandaki uygulamayi DURDUR (ZORUNLU)
Testler bitince background task'i sonlandir (`KillShell`; gerekirse `kill $(lsof -ti tcp:$PORT)`).
Playwright session aciksa `playwright-cli close`. Hata/iptal durumunda da yapilir — orphan
process/port birakilmaz.

> Kanit dosyalari canli credential/JWT icerebilir → her zaman `/tmp` altinda, **repo disi**.
> Analiz sayfasinda gosterilen gorselleri secerken de credential icermediklerini dogrula.

---

## Adim 8 — Analiz Sayfasi Grup 3 (B8–B11) + sohbet kapisi

Ayni HTML dosyasina son dort bolumu EKLE ve tekrar `open` ile ac:

- **B8 — Acik Konular (kapanis durumu)**: B6'daki her maddenin verilen karari + uygulanma durumu;
  is sirasinda dogan yeni acik konu varsa acikca listele
- **B9 — Kanitlar**: `$EVID/` ciktilari — screenshot'lar goreli yolla gosterilir (sayfa ayni
  klasorde), test/diff/API ciktilarindan karar verdirici kisimlar; her kanitin NEYI ispatladigi
  tek cumleyle
- **B10 — Ek Kazanclar**: cozum sirasinda elde edilen yan iyilestirmeler (temizlenen kod,
  kapatilan baska bug, performans kazanci)
- **B11 — Son Durum / Yeni Akis / Ozellik Tanitimi**: cozum sonrasi sistemin davranisi — yeni
  akis semasi, once/sonra karsilastirmasi; degisiklik bir ozellikse kisa tanitim

Sonra **sohbet kapisi**: `AskUserQuestion` (header: "Akis") — options:
`["Commit skill calistir", "Duzenleme/istek var", "Iptal"]`.

- **Duzenleme/istek var** → istegi al; kod degisikligi gerekiyorsa Adim 7'ye don (test+kanit
  yenile), sayfayi guncelle, tekrar sor. Kullanici "commit skill calistir" diyene kadar bu
  adimda kalinir
- **Iptal** → worktree'yi `ExitWorktree({ action: "keep" })` ile birak, durumu raporla

---

## Adim 9 — Commit skill

`commit` skill'e delege et (teslimat: commit/push/PR; tum kontrolleri o yapar — `before-commit`
kurali geregi manuel git yok). Worktree'den PR icin `worktree` skill `pr <isim>` akisi kullanilabilir.
Plane kapama (completed + label/priority/target-date) `commit` skill'in Adim 10/10a sorumlulugudur.

---

## Akis Ozeti

```
1. CLAUDE.local.md "## Issue Workflow" oku          (proje-ozel komut/port/test/akis notu)
2. Kaynak toplama — TAM detay, ANA AJAN             (plane-cli / Read / markitdown / WebFetch / diji-logs)
3. HTML B1+B2+B3 yaz + `open` (lokal browser)       → SOHBET KAPISI ("Akisa devam et" gelene kadar duzenle/sohbet)
4. HTML B4+B5+B6+B7 — ULTRATHINK, ANA AJAN          (acik konular KAPATILIR, riskler durust) → SOHBET KAPISI
5. Worktree ac (worktree skill) + EnterPlanMode     (tam plan; Workflow ile paralelize edilebilir) → ExitPlanMode onayi
6. Plane issue ise ISLEME AL — OTOMATIK             (started + self + start_date; dolu olana dokunma; idempotent)
7. Uygula → test ortami → unique port + arka plan → kanit ($EVID; gorselde SCREENSHOT zorunlu) → DURDUR
8. HTML B8+B9+B10+B11 ekle + `open` → SOHBET KAPISI ("Commit skill calistir" gelene kadar duzenle/sohbet)
9. commit skill                                      (teslimat + Plane kapama orada)
```

## Entegrasyon Notlari

- **Delegasyon**: worktree → `worktree` skill, teslimat → `commit` skill, log → `diji-logs`
  (kapsamli tarama `log-triage`), Plane → `plane-cli` skill, sayfa tasarimi → `artifact-design` skill
- **Analiz sayfasi**: LOKAL HTML (`/tmp/<isim>/analiz.html`), **Artifact tool ile YUKLENMEZ** —
  `open` ile default browser'da acilir; TEK dosya, buyuyerek; gorsel-agir, metin kisa; ilk
  yazimdan once `artifact-design` yuklenir; kanit gorselleri goreli yolla
- **Sohbet kapilari**: Adim 3, 4, 8 — kullanici acik onay verene kadar adimda kalinir, sayfa
  uzerinde iterasyon yapilir. Onay sorusu her zaman `AskUserQuestion` ile (`ask-first` kurali)
- **Sub-agent siniri**: Adim 2 (kaynak) ve Adim 4 (analiz) asla sub-agent'a verilmez; `Task`
  yalniz `obsidian-searcher` on aramasi ve Adim 7 kanit uretiminde kullanilabilir
- **Plan onayi**: tek onay noktasi `ExitPlanMode` (Adim 5); acik konular ondan ONCE (Adim 4,
  B6) kapatilmis olur — plan modunda yeni tartisma acilmaz
- **Plane isleme alma**: plan onayi SONRASI (Adim 6) — otomatik, onaysiz, idempotent; kapama
  `commit` skill'de
- **Test ortami**: worktree'de izole, unique port, arka plan, is bitince ZORUNLU durdurma
- **Kanit izolasyonu**: her zaman `/tmp/<isim>/` — repo'ya kanit/credential sizmaz; artifact'e
  gomulen gorselde credential kontrolu
- **Durus**: agent uzman — dogru olani sec, esteti arastir, global standarda bak, imkansizi
  durust soyle, ek kazanimi raporla

## Ek — `CLAUDE.local.md` "## Issue Workflow" Sablonu

Bu bolumu calisilan projenin `CLAUDE.local.md`'sine ekle (proje-ozel; commit edilmez). Skill Adim 1'de okur.

```markdown
## Issue Workflow

- **Bagimlilik kurulum**: <orn `uv venv && source .venv/bin/activate && uv pip install -r requirements.txt`>
- **Baslatma komutu**: <orn `.venv/bin/python manage.py runserver 127.0.0.1:$PORT`>
- **Test komutu**: <orn `pytest`, `npm test`, `playwright test`>
- **Port**: unique (otomatik) | sabit gerekiyorsa: <port>
- **Ek servisler**: <orn redis/postgres gerekli mi, nasil ayaga kalkar>
- **Akis notlari**: <bu projede dikkat edilecekler, kullanici-ozel kurallar>
```
