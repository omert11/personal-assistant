---
name: issue-workflow
description: Issue/ticket/doc/gorsel kaynagini analiz eder, worktree acar, cozer, kanit toplar.
when_to_use: Trigger — "su ticket'i coz", "issue-workflow ile bak", "bu hatayi worktree'de coz", "ticket analiz et ve duzelt", "su dokumandaki sorunu hallet", "/issue-workflow <ref|metin>". Bir issue/ticket/dokuman/gorsel/mesaj kaynagi verilip uctan uca (analiz → izole worktree → cozum → kanit → onay) cozulmesi istendiginde. Tek seferlik kucuk duzeltmeler icin gerekmez; kok-neden analizi + izolasyon + kanit gerektiren islerde.
argument-hint: <ticket-ref | serbest-metin | dosya-yolu>
disable-model-invocation: false
effort: max
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion, Task, WebFetch, EnterWorktree, ExitWorktree, Skill
---

# Issue Workflow — Analiz → Izole Worktree → Coz → Kanit → Onay

Verilen bir **kaynagi** (Zammad ticket, serbest metin, dokuman, gorsel, mail, log)
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

## Adim 0 — Kaynagi tam analiz et ve contexte al (ATLANAMAZ, ANA AJAN)

Kullanicinin verdigi her kaynagi **tek tek, tam** incele. Hicbirini atlama, ozetle gecme.
**Bu adim sub-agent'a verilmez** — kaynagi ana ajan kendi context'inde okur (yukaridaki sub-agent yasagi).

| Kaynak tipi | Nasil al |
|---|---|
| **Zammad ticket no** (`#61618`, `61618`) | `zammad-cli` skill → `ticket get` + `ticket articles` (tum yazismalar) + ekler. Ekli gorsel/dosya varsa indir ve oku |
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
- Zammad ticket → `fix-<ticketno>` (orn `fix-61618`)
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

> Rapor **onay mekanizmasi DEGIL** — final yazildi diye durma. Kesinlik KESIN ise dogrudan Adim 3'te
> uygulamaya gec; raporu kullaniciya gostermek yeterli, "onayliyor musun?" diye SORMA.

---

## Adim 3 — Karar: uygula veya sor (MUHAFAZAKAR)

**Cozum KESIN ise** (hepsi saglanmali) → dogrudan uygulamaya basla:
- Tek olasi kok neden var, kanitla dogrulandi
- Net, tek bir dogru duzeltme var
- Yan etki riski dusuk / izole

**Cozum BELIRSIZ ise** (herhangi biri) → **DUR**, `AskUserQuestion` ile sor:
- Birden cok olasi kok neden / duzeltme yolu var
- Degisiklik genis yuzeyi etkiliyor, breaking olabilir
- Urun/UX karari iceriyor (kullanici tercihine bagli)
- Eksik bilgi var (hangi ortam, hangi davranis bekleniyor)

> En ufak belirsizlikte SORMAK varsayilandir. Yanlis varsayimla ilerlemek pahalidir.
> `ask-first` kurali: her soru `AskUserQuestion` tool ile — duz metin soru yasak.

Uygularken `coding` kurallarina uy: hata wrap, TODO yorumlari, gereksiz workaround yok,
"daha zarif yol var mi?" self-check.

---

## Adim 4 — Kanit topla (`/tmp/<isim>/` altina)

Calisma tamamlaninca, **sorunun cozuldugune dair kanitlari** topla. Klasor:

```bash
EVID=/tmp/<isim>
mkdir -p "$EVID"
```

Soruna uygun araclarla kanit uret (her birini `$EVID/` altina dosya olarak yaz):

| Sorun tipi | Kanit araci | Cikti |
|---|---|---|
| Frontend / UI / akis | `playwright-cli` skill | `$EVID/screenshot-*.png`, adim adim snapshot |
| API / backend endpoint | `curl`/`Bash` | `$EVID/api-before.json`, `$EVID/api-after.json` |
| Mantik / fonksiyon | test (`pytest`/`npm test`) | `$EVID/test-output.txt` (PASS) |
| Veri / DB / log | shell sorgu | `$EVID/query-result.txt` |
| Her durum | before/after diff | `$EVID/diff.txt` (`git diff > ...`) |

Ayrica `$EVID/SUMMARY.md` yaz:
- Kok neden (1-2 cumle)
- Yapilan degisiklik (dosya + ozet)
- Her kanit dosyasinin neyi ispatladigi (orn "api-after.json — artik 200 donuyor, onceden 500")

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
0. Kaynagi tam analiz et + contexte al        (zammad-cli / Read / markitdown / WebFetch / diji-log-search)
1. Worktree ac + /tmp/<isim>/REPORT.md ac      (worktree skill; REPORT zed ile acilir — takip icin, onay DEGIL)
2. Kok-neden analizi — ULTRATHINK              (effort: max; canli "Anlik Bulgular" → sonda "Final Rapor")
3. KESIN → uygula (sorma) | BELIRSIZ → AskUserQuestion (muhafazakar)
4. Kanit topla → /tmp/<isim>/                  (playwright-cli / curl / pytest / git diff)
5. zed ile ac → AskUserQuestion onay → commit skill
```

> REPORT.md (takip, onay beklemez) ile Adim 5 kanit-onayi farkli seylerdir: rapor analizi izlemek
> icin akarken yazilir; Adim 5 onayi cozum uygulandiktan sonra kanitlar uzerinden alinir.

## Entegrasyon Notlari

- **Worktree**: mantik `worktree` skill'de — bu skill sadece `new <isim>` cagirir, isim turetir
- **Teslimat**: commit/push/PR mantigi `commit` skill'de — `before-commit` kurali geregi manuel git yok
- **Log analizi**: diji b2c projede `diji-log-search` skill'e delege (basket lifecycle)
- **Kaynak donusum**: PDF/Office → `markitdown`, URL → `WebFetch`, gorsel → `Read`
- **Takip raporu**: `/tmp/<isim>/REPORT.md` calisma basinda olusur, zed ile acilir, analiz akarken guncellenir — yalniz **izleme** icindir, hicbir adimda onay/etkilesim beklemez
- **Kanit izolasyonu**: her zaman `/tmp/<isim>/` — repo'ya kanit/credential sizmaz
- **Karar felsefesi**: muhafazakar — supheliysen uygulama, sor (`ask-first` kurali)
- **Sub-agent siniri**: Adim 0 (kaynak analizi) ve Adim 2 (kok-neden) **asla** `Task`/sub-agent'a verilmez — baglamdan kopar, kritik analiz bozulur. `Task` yalniz `obsidian-searcher` on aramasi ve Adim 4 kanit-uretiminde (playwright vb.) kullanilabilir
