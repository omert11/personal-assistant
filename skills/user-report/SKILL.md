---
name: user-report
description: Yapılan işi veya bir konuyu report-kit ile tek dosyalık, etkileşimli HTML rapor olarak sunar.
when_to_use: Trigger — "rapor hazırla", "görsel özet", "yaptıklarımızı özetle", "önce/sonra göster", "html rapor", "/user-report". Kullanıcı bir işin, analizin veya karşılaştırmanın tek bakışta görsel özetini istediğinde.
argument-hint: [konu]
---

# User Report

## İçerik

- Her sayı repo, dosya sistemi, sorgu veya komut çıktısından ölçülür; kaynağı `src` veya `sources` ile yazılır.
- Önce `sum` (tek satır) ve `kpi`, sonra detay. Metin kısa: etiket ve kısa cümle.
- Değişiklik varsa önce/sonra: `diff`, `chart`, `img` (before/after).
- Bekleyen işler `todo`, riskler `risk`.
- Kullanıcı kararı gerekiyorsa tahmin etme: `ask` / `review`, her soru ve maddeye sabit `id`.
- `"lang":"tr"`.

## Dosya

`/tmp/<konu-slug>.html`; yalnız JSON yazılır, HTML/CSS/grafik kodu yazılmaz:

```html
<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://cdn.jsdelivr.net/gh/omert11/report-kit@0.3.0/report-kit.min.js"></script>
<script type="application/json" class="rk-v">{ ...v1... }</script>
```

Sürüm: `{"title","sum","meta":[çipler],"date","note":"ne değişti","lang","blocks":[...]}`. `title`, `sum`, `meta`, `lang` önceki sürümden miras alınır.

## Bloklar

Blok bir nesne; tip anahtarı veriyi taşır. Her blokta opsiyonel: `title`, `icon` (Lucide adı), `id`, `src`. Satır içi: `**kalın**`, `` `kod` ``, `[metin](https://url)`. Ton: `good` `bad` `warn` `info`.

```
{"h":"Bölüm"}
{"p":"Paragraf"}
{"callout":"Metin","tone":"warn"}
{"kpi":[["Etiket",değer,"ton","alt","icon"]]}
{"progress":[["Etiket",7,10,"ton"]]}                 max varsayılan 100
{"diff":{"before":{"k":1},"after":{"k":2}},"good":"down"}
{"chart":"bar|hbar|stacked|line|area|pie|doughnut|radar","x":["a","b"],"y":{"Seri":[1,2]}}   y düz dizi olabilir
{"flow":"flowchart LR\n A-->B"}                      herhangi bir Mermaid diyagramı
{"table":[["H1","H2"],["a",1]],"total":true}         veya [{"H1":"a","H2":1}]
{"timeline":[["14 Eki","Metin","good"]]}
{"code":"kaynak","lang":"diff"}
{"copy":"yapıştırılacak metin","text":"açıklama"}
{"risk":[["Metin","high|med|low"]]}
{"todo":["açık madde",["biten madde",true]]}
{"review":[["id","Onaylanacak madde"]]}
{"ask":[{"id":"q1","q":"Soru?","opt":["A","B"],"multi":false},{"id":"q2","q":"Serbest metin?"}]}
{"faq":[["Soru","Cevap"]]}
{"img":{"before":"a.png","after":"b.png"},"labels":["Önce","Sonra"],"cap":"Açıklama"}   veya "img":"url"
{"sources":[["Ne","cmd|file|link|db","komut, yol veya URL"]]}
{"tabs":{"Sekme A":[bloklar],"Sekme B":[bloklar]}}
{"cols":[blok,blok]}
{"details":"Özet","blocks":[bloklar]}
{"ref":"id"}                                         önceki sürümdeki aynı id'li bloğu kullanır
```

- Grafik serileri `x` ile, tablo satırları başlıkla aynı uzunlukta.
- Görseller mutlak yol veya `data:image/...` URI.

## Doğrulama ve teslim

1. `npx --yes github:omert11/report-kit /tmp/<konu-slug>.html`; her sorunu düzelt, `ok` görene kadar tekrar çalıştır.
2. Kullanıcının varsayılan tarayıcısında aç: `open /tmp/<konu-slug>.html`.
3. Sohbete dosya yolu + bir satır özet.

## Geri bildirim

Kullanıcı "my responses" / yanıt bloğu yapıştırırsa: yanıtları uygula, dosyanın sonuna yeni `<script type="application/json" class="rk-v">` ekle (`note` ile ne değiştiği); önceki sürümlere dokunma, değişmeyen bloklar `{"ref":"id"}`.
