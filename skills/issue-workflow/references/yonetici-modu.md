# Yonetici Modu — Fazli Sub-agent Orkestrasyonu, Sonda Tek Kontrol

`issue-workflow` Adim 4'te yonetici modu secildiyse Adim 7'nin yerine gecer (7Y); diger adimlar (1-6, 8-10) aynen. Tek worktree.

## 1. Ilkeler (esnetilmez)

1. Ara commit, ara build, ara review, asamali teslim YOK; kirik ara durum normal. Tek PR.
2. Tum is tek orkestrasyon: fazlar ardisik sub-agent dalgalari (faz icinde paralel, fazlar arasi bariyer). Ikinci uygulama orkestrasyonu veya paralel orkestrasyon YOK.
3. Ilk faz zorunlu olarak sozlesme fazi (Bolum 3).
4. Sub-agent'lar yalniz yazar: test/build/lint/format/git/uygulama baslatma yasak; salt-okuma self-check serbest.
5. Dogrulama ve kanit ana agentta, sonda, tek seferde. Code-review yalniz Adim 9'da `commit` skill'de.
6. Ana agent is bitene kadar durmaz (Bolum 8).

## 2. Akis

```
[Ana agent] SUB-AGENT FAZLARI: Sozlesme -> Faz A (paralel) -> Faz B (paralel) -> ...   (Bolum 3-4)
   |
   +-> tum sub-agent'lar bitti -> ARA RAPOR YAZMA, dogrudan dogrulamaya gec
   |
   +-> DOGRULA (Bolum 6): git diff + build + test + lint   [ana agent, arka plan, cikti $EVID/*.log]
   |
   +-> hata varsa -> FIX SUB-AGENT'LARI (Bolum 7)   (dogrulama tek tur; fix sonrasi tekrar dogrulama yok)
   |
   +-> KANIT (Bolum 9 / Adim 7a-7d, ana agent): uygulamayi ayaga kaldir, screenshot/API/test, DURDUR
   |
   +-> Adim 8 log temizligi -> 9 commit skill (review + tek PR) -> 10 sonuc raporu
```

Durum takibi: gorev listesi (faz basina bir gorev). Kalici kayit worktree'nin kendisi; sonda tek commit.

## 3. Sozlesme fazi

Ilk faz tek sub-agent; yalniz iskelet uretir, is mantigi yazmaz:

- Fonksiyon/metot/sinif imzalari, tip, arayuz/protokol tanimlari
- Endpoint/route semasi, request-response sekilleri
- Modul dosyalari (bos govde + `TODO: <gorev kodu>`), import iskeleti
- Sabitler, enum'lar, hata tipleri, migration numara blogu

Kurallar:
- Ciktisi (`files_changed`) sonraki fazlarin brief'ine acikca yazilir; sonraki sub-agent'lar once bu dosyalari okur, sonra govdeyi doldurur
- Sozlesme disina cikmak gereken sub-agent imza degistirmez, `open_questions`'a yazar

## 4. Sub-agent fazlari

Ana agent fazlari sirayla yurutur; her fazda o fazin sub-agent'larini ayni anda (paralel) spawn eder, hepsinin RAPOR'unu toplar, sonra sonraki faza gecer. Her sub-agent'a: brief (Bolum 5), model/effort (`core` kuralindaki tablo) ve asagidaki RAPOR semasi (son mesaj yalniz bu JSON) verilir.

| Sira | Faz | Sub-agent'lar | Girdi |
|---|---|---|---|
| 0 | Sozlesme | tek sub-agent (`sozlesme`) | sozlesme brief'i (Bolum 5) |
| 1 | Faz A | G1, G2, ... paralel (dosya-ayrik) | gorev brief'i + `SOZLESME DOSYALARI (once oku): <sozlesme.files_changed>` |
| 2 | Faz B | G3, ... paralel — A bittikten sonra | ayni |

RAPOR semasi (her sub-agent'in zorunlu ciktisi):

```json
{
  "type": "object",
  "required": ["gorev", "status", "files_changed", "summary"],
  "properties": {
    "gorev": { "type": "string" },
    "status": { "type": "string", "enum": ["done", "blocked"] },
    "files_changed": { "type": "array", "items": { "type": "string" } },
    "summary": { "type": "string" },
    "assumptions": { "type": "array", "items": { "type": "string" } },
    "open_questions": { "type": "array", "items": { "type": "string" } }
  }
}
```

Toplama: ana agent her fazin sonunda `{ faz, gorevler: [RAPOR...] }` kaydini tutar ve "<faz> bitti — <done>/<toplam>" durumunu gorev listesine yazar. Sonuc: `{ sozlesme, fazlar }`.

Basarisizlik / asilma: RAPOR donmeyen, semaya uymayan veya takilan sub-agent ayni brief ile yeniden spawn edilir; biten sub-agent'larin RAPOR'lari yeniden kullanilir, yeniden kosturulmaz. Faz, tum gorevleri RAPOR donmeden kapanmaz.

### Faz kurma
- Ciktisi baska gorevin girdisi olan gorevler ayni fazda olamaz → sonraki faz
- Ayni dosyaya yazan iki gorev ayni fazda paralel olamaz: birlestir ya da ayni faz icinde ardisik sub-agent
- Gorev basina yazilabilir dosya yollari Adim 5 planindan gelir

### Tavan (M1 Pro 8 cekirdek / 16 GB)
- Bir fazda esszamanli <= 6 sub-agent
- Toplamda <= 15 sub-agent; is buyukse esszamanli sub-agent sayisini degil faz sayisini artir
- Item bazinda zincir gerekiyorsa (bir item'in adimlari ardisik, item'lar birbirini beklemez) her item icin zinciri ayri yurut; fazlar arasi bariyer bekleme

## 5. Sub-agent brief sablonu

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
- Proje anayasasi gecerlidir: ~/.claude/rules/core.md + AGENTS.md
  (hata wrap, TODO yorumu, workaround yok; Ingilizce kod yorumu).
- Kritik akis noktalarina [<SESSION_NAME>] prefix'li log ekle (dilin logger'i varsa).
- Yazdiktan sonra dosyalarini geri okuyup tutarliligi kontrol et (import/isim/imza).
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

Sozlesme fazi brief'i ayni sablon; farklar: "yalnizca iskelet uret — imza, tip, sema, bos govde + `TODO: <kod>`; is mantigi YAZMA", kapsam tum moduller.

## 6. Dogrulama (ana agent, sonda, tek sefer)

Sirayla, hepsi arka planda, ciktilar dosyaya:

```bash
EVID=/tmp/issue-<isim>
git diff --stat                                   # iddia edilen dosyalar gercekten degisti mi
heavy <build komutu>  > "$EVID/build.log" 2>&1    # agir build/test heavy slot kuyrugundan gecer
heavy <test komutu>   > "$EVID/test.log"  2>&1
<lint/type-check>     > "$EVID/lint.log"  2>&1
```

- Build/test ana agentta kalir; paralel sub-agent'lara dagitma.
- Logu context'e alma: `tail`/`grep -c error` ile ozet oku; ham ciktiyi fix sub-agent'ina dosya yolu olarak ver.
- `git status --short` ile beklenmeyen dosya degisikligi (dosya siniri ihlali) kontrol et.

## 7. Fix sub-agent'lari

Hatalari dosya bazinda grupla; tek faz (`Fix`), her grup bir sub-agent, hepsi paralel (tavan Bolum 4), cikti RAPOR semasi. Brief:

```
Su dosyalardaki hatalari gider: <grup dosyalari>
Hata ciktisi: <log yolu> — bu dosyayi OKU, ilgili satirlari bul.
Yasaklar ayni: test/build/lint/git YOK, sadece kodu duzelt.
```

- Ayni dosyaya iki fix sub-agent'i yazmaz
- RAPOR donmeyen fix sub-agent'i yeniden spawn edilir
- Dogrulama tek tur: fix sonrasi Bolum 6 tekrar kosmaz
- Kucuk hata (<=3 satir, tek dosya) → sub-agent spawn etme, ana agent inline duzeltir
- Mimari ihlal (guvenlik acigi, yanlis pattern, para icin float, auth'suz uc) → DUR, soru araciyla sor (header: "Ihlal", `["Duzelt", "Gormezden gel"]`)

## 8. Kesintisiz yurutme

Turu kapatmanin izinli uc hali:
1. Is bitti, Adim 10 sonuc raporu yazildi
2. Sert durak (mimari ihlal, cozulemeyen hata, kullanici karari gerektiren belirsizlik)
3. Kullanici akisi kesti

Disinda:
- Sub-agent bitisi gelince ara rapor yazma, dogrudan sonraki adima gec
- Arka planda sub-agent varken bosta durma (gorev durumunu guncelle, fix brief'lerini hazirla)
- Asilma supheli → gorev listesini ve arka plan ciktilarini tara; biten sub-agent'larin RAPOR'larini koru, bitmeyenleri yeniden spawn et
- On planda `sleep` kullanma

## 9. Kanit ve kapanis

Kanit ana agentta, standart Adim 7a-7d: worktree'de kurulum → unique port + arka planda uygulama → screenshot/API/test ciktilari `$EVID/` altina → uygulamayi durdur.

- Sub-agent'lara dagitma (tek tarayici ornegi; uygulamayi baslatan/durduran taraf tek olmali).
- Gorsel degisiklikte screenshot zorunlu.

Sonra: Adim 8 (log temizligi) → Adim 9 (`commit` skill: code-review + tek commit + tek PR + Plane kapama) → Adim 10 (sonuc raporu; faz kirilimi + kanitlar).

## 10. Durustluk

- "Sub-agent'lar bitti" kanit degil; kanit `git diff` + kosturulan komutun ciktisi.
- Sub-agent'larin `assumptions`/`open_questions` alanlarini oku ve raporla; is akisini degistiren varsayimi sonuc raporuna yaz.
- Kismen biten faza "bitti" deme; ne bitti / ne kaldi ayri yaz.
- Sonda tek kontrol hafifletilmez: build, test, lint ve review'in tamami kosar.
