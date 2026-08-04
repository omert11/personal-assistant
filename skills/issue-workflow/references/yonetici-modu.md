# Yonetici Modu — Ana Agent Yonetir, Ekip Yazar, Ana Agent Dogrular

`issue-workflow` Adim 4.5'te yonetici modu secildiyse bu dosya gecerlidir. Standart akisin
**Adim 7'si** burada tarif edilen **7Y** ile degistirilir; diger adimlar (1-6, 8, 8.5, 9, 10)
aynen kalir. Adim 5 (worktree + plan modu) da degismez — **tek worktree** kullanilir.

**Ozet:** orta olcekli is. Ana oturum **kod yazmaz**: isi ayrik dosya kumelerine boler, brief
yazar, subagent'lara yaptirir; sonra **kendisi dogrular ve kanitlari kendisi uretir**. Faz/WP
orkestrasyonu, ayri worktree, merge turu YOK.

> **Neden dogrulama ana agentta:** isi yapan taraf kendi isini onaylayamaz. Kodu subagent yazdi,
> ana agent yazmadi — dolayisiyla ana agent bagimsiz dogrulayici konumundadir. Faz modundaki
> "ayri dogrulayici agent" katmani bu olcekte gereksiz maliyettir.

---

## 1. Ne zaman yonetici modu

| Olcut | Yonetici modu | Faz modu |
|---|---|---|
| Is paketi sayisi | 2-4 | 5+ veya sirali fazlar |
| Sirali baglilik | Yok (hepsi paralel yurur) | Var (birinin ciktisi digerinin girdisi) |
| Dosya kumeleri | Ayrik, tek worktree'de yonetilebilir | Cakisma riski yuksek, izolasyon sart |
| Sure | Tek oturumda biter | Coklu faz, oturum asabilir |

Ikisi arasinda tereddutteysen **yonetici modu** sec — daha ucuz, gerekirse is buyudugunde faz
moduna gecilir (karar analiz sayfasina yazilir).

---

## 2. Roller

| Rol | Kim | Sorumluluk | Yasak |
|---|---|---|---|
| **Yonetici** | Ana oturum | Isi boler, brief yazar, subagent baslatir, ciktilari dogrular, uygulamayi ayaga kaldirir, **kanitlari uretir**, analiz sayfasini/commit'i yurutur | Kural olarak kod yazmaz (istisna: Bolum 5); "subagent yapti" diyerek dogrulamadan gecmez |
| **Ekip** | Subagent (`Agent`, `model: opus`) | Verilen dosya kumesinde kodu yazar, kendi isini derler/hizli kontrol eder, JSON rapor doner | Dosya sinirini asmaz, commit/push/merge yapmaz, worktree acmaz, kapsam disina cikmaz |

---

## 3. Adim 7Y — Akis

```
[Yonetici] isi 2-4 ayrik pakete bol (dosya kumeleri ORTUSMEZ)
   |
   +-> TaskCreate ile paketleri listeye yaz (kullanici ilerlemeyi gorur)
   |
   +-> her paket icin brief yaz -> Agent (name: ip-<kod>, model: opus) arka planda baslat
   |   ortusen dosya varsa o paketler PARALEL DEGIL, sirali kosar
   |
   +-> (rapor geldikce) yonetici DOGRULAR: diff oku, cikis olcutunu kendi kostur
   |
   +-> gecti -> paketi tamam isaretle (TaskUpdate)
   |   kaldi -> ayni agent'a SendMessage ile bulgular (tur +1); tur 2'de hala olmuyorsa devral
   |
   +-> tum paketler tamam -> ana agent kanit uretir (Adim 7a-7d aynen)
```

### Subagent baslatma
```
Agent({
  name: "ip-<kod>",
  subagent_type: "general-purpose",
  model: "opus",              // yazan el opus; salt-okunur envanter isi icin sonnet
  prompt: <brief>
})
```
`name` sarttir — duzeltme turu `SendMessage({ to: "ip-<kod>" })` ile ayni agent'a, baglami
korunarak gider. Arka planda kosarlar; bitis bildirimi geldikce yonetici dogrular.

### Kanit uretimi ana agentta
Tum paketler dogrulandiktan sonra standart **Adim 7a-7d** ana agent tarafindan kosulur:
worktree'de bagimlilik kurulumu → unique port + arka planda uygulama → testler/screenshot/API
ciktilari `$EVID/` altina → **uygulamayi durdur**. Gorsel degisiklikte screenshot zorunlu.

`[SESSION_NAME]` loglama kurali degismez: subagent'lar brief geregi loglari ekler, temizligi
Adim 8.5'te ana agent yapar (bloklayici).

---

## 4. Brief sablonu (subagent)

```
Sen IP-<kod> paketini uyguluyorsun: <alan adi>.

HEDEF
<tek paragraf: ne bitmis olacak>

KAPSAM (bunlar ve yalniz bunlar)
- <madde>

KAPSAM DISI
- <acikca yapilmayacaklar>

CALISMA DIZINI
- <worktree yolu> — ZATEN ACIK. Worktree ACMA, branch ACMA, dizin degistirme.

DOSYA SINIRI
- Yazabilecegin yollar: <liste>
- DOKUNMA (baska paketin): <liste>

CALISMA KURALLARI
- Proje anayasasi gecerlidir: CLAUDE.md + CLAUDE.local.md + ~/.claude/rules/
  (hata wrap, TODO yorumu, workaround yok; Ingilizce kod yorumu).
- Kritik akis noktalarina [<SESSION_NAME>] prefix'li log ekle (dilin logger'i varsa).
- Kendi subagent'ini kullanacaksan model ACIKCA yaz (yazan is -> opus, salt-okunur arama -> sonnet).

CIKIS OLCUTU
- <olculebilir maddeler>
- Isini derle/hizli kontrol et (syntax/build/ilgili birim testi) — YARIM TESLIM ETME.
  Uygulamayi ayaga kaldirma, screenshot/kanit uretme: onu yonetici yapacak.

YASAKLAR
- commit / push / merge / PR / tag YOK — teslimat yoneticinin isi
- git stash yok, --force yok, --no-verify yok
- Dosya sinirin disina yazma; ihtiyacin varsa raporunda open_questions'a yaz

RAPOR (son mesajin SADECE bu JSON olsun)
{ "paket": "...", "status": "done|blocked",
  "files_changed": ["..."],
  "exit_criteria": [{"item": "...", "met": true, "evidence": "<komut + cikti ozeti>"}],
  "assumptions": ["..."], "open_questions": ["..."], "notes": "..." }
```

---

## 5. Dogrulama protokolu (yonetici kendi yapar)

Her paket raporu icin, **rapora guvenmeden**:

1. **Diff oku** — `git diff` / `git diff --stat`: iddia edilen degisiklikler gercekten var mi,
   fazladan ne degismis
2. **Cikis olcutlerini kendin kostur** — build/test/curl; subagent'in ciktisini kopyalama, komutu
   tekrar calistir
3. **Dosya siniri ihlali** — paketin disina yazilmis mi (`git diff --name-only` ile karsilastir)
4. **Anayasa uygunlugu** — CLAUDE.md / CLAUDE.local.md / `~/.claude/rules/`; `coding` kurali
   (hata wrap, workaround yok, TODO)
5. **Sessiz gerileme** — mevcut davranisi bozan degisiklik var mi

Kural: **kanitsiz gecis yok.** Bir olcutu kosturamadiysan "gecti" sayma; ya kostur ya duzeltme
turu ac.

### Duzeltme turu
- **Tur 1**: bulgulari `SendMessage` ile ayni agent'a gonder (komut + gercek cikti ile; "su testi
  kosturdum, su hatayi verdi")
- **Tur 2 sonunda hala olmuyorsa**: yonetici **devralir ve kendisi duzeltir** — bu, ana agent'in
  kod yazabilecegi tek rutin istisnadir (digeri: paketler arasi trivial yapistirma/entegrasyon
  satiri). Devralma analiz sayfasinda belirtilir.
- **Mimari ihlal** (guvenlik acigi, yanlis pattern, para icin float, auth'suz uc): tur sayisina
  bakma — DUR, `AskUserQuestion` ile kullaniciya bildir (`coding` kurali).

---

## 6. Cakisma protokolu (tek worktree)

1. **Dosya kumeleri ortusmez** — ayni dosyaya iki agent yazamaz. Ortusuyorsa paketler paralel
   degil **sirali** kosar (biri bitip dogrulandiktan sonra digeri baslar).
2. Ortak/paylasilan dosya (route tablosu, i18n katalogu, settings) tek pakete verilir; digerleri
   ihtiyacini `open_questions`'a yazar, yonetici sonda uygular.
3. Migration/numara/sira gerektiren kaynaklar yonetici tarafindan blok halinde dagitilir.
4. Paralel kosan agent'lar ayni worktree'dedir: hicbiri `git checkout`/`stash`/`reset` **yapmaz**
   (brief'te yasakli).

---

## 7. Model politikasi

`token-efficiency` kurali + faz modundaki tabloyla ayni:

| Is | Model |
|---|---|
| Kod/sema/test/refactor/dokumantasyon yazan subagent | `opus` |
| Salt-okunur envanter/arama/log tarama | `sonnet` |
| `haiku` | Kullanilmaz |

Her `Agent` cagrisinda `model` acikca yazilir. ⛔ **Fable Model Baraji** (SKILL.md Adim 5) burada
da gecerli: fable oturumunda hicbir agent fable ile kosmaz, ust sinir `opus`.

---

## 8. Durustluk ve standart akisla birlesme

- Rapor edilirken **kimin ne yaptigi ayrilir**: "IP-A subagent tarafindan uygulandi, dogrulamayi
  ben kosturarak yaptim (komut + cikti)". "Subagent yapti, gecti" tek basina kanit degildir.
- Bir paket kismen bittiyse "bitti" denmez; ne bitti / ne kaldi ayri yazilir.
- Ilerleme `TaskCreate`/`TaskUpdate` ile canli tutulur (`workflow` kurali) — ayri durum dosyasi
  tutulmaz; is tek oturumda biter.
- Analiz sayfasina (`~/.pa-render/active/<isim>/index.html`) **B8/B9**'da paket kirilimi islenir:
  hangi paketi kim uyguladi, dogrulama kaniti ne, devralma oldu mu.
- Sonra standart akis: **Adim 8** (B8-B11) → **Adim 8.5** (`[SESSION_NAME]` temizligi, bloklayici)
  → **Adim 9** (`commit` skill) → **Adim 10** (arsivle).
- Is beklenenden buyurse (paket sayisi 5+'a cikti, sirali baglilik dogdu): **faz moduna gec** —
  `references/faz-modu.md` yuklenir, gerekce analiz sayfasina yazilir.
