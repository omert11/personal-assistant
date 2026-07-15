---
name: user-render
description: Kullaniciya gorsel HTML sayfasi uretir/gunceller (PA Render, hazir UI kit).
when_to_use: Trigger — "analiz sayfasi yaz", "gorsel sun", "render et", "sayfayi guncelle", "/user-render". Kullaniciya bir konuyu gorsel sayfayla anlatmak/sunmak gerektiginde (analiz, karsilastirma, plan, kanit, rapor). Artifact tool yerine HER ZAMAN bu skill; issue-workflow analiz sayfalari da buradan yazilir.
argument-hint: <konu-slug | serbest istek>
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# user-render — Kullaniciya Gorsel Sayfa Uret

Kullaniciya gosterilecek her gorsel HTML sayfasi bu skill ile uretilir. Sayfa **lokal dosyadir**;
takibi kullanici kendi tarafinda yapar. **Sen yalniz dosyayi yazar/guncellersin — sunmaz, acmaz,
server yonetmezsin.** Artifact tool KULLANILMAZ.

## Dosya Duzeni

```
~/.pa-render/
  active/<konu-slug>/index.html    ← sayfa (TEK dosya, buyuyerek Edit'lenir)
  active/<konu-slug>/...           ← kanit/gorsel/ek dosyalar (klasor disina SIZMAZ)
  archive/<konu-slug>/             ← biten isler (asagida Arsivleme)
```

- `<konu-slug>`: kebab-case, isin kisa adi (orn `fix-hotel-region`, `feat-multi-city-flight`)
- Giris dosyasi **her zaman `index.html`**; gorseller ayni klasorde, sayfada **goreli yolla**
  (`<img src="screenshot-after.png">`)
- Yeni bolumler ayni dosyaya `Edit` ile EKLENIR; konu basina yeni dosya ACILMAZ
- Kanit dosyalari canli credential/JWT icerebilir → her zaman bu klasorde, **repo disi**

## Sayfa Iskeleti — UI kit ZORUNLU, inline CSS YASAK

```html
<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>…</title>
<link rel="stylesheet" href="/lib/pa.css">
<script type="module" src="/lib/pa.js"></script>
</head>
<body>
<main> … </main>
</body>
</html>
```

Tasarim sistemi (cift tema, tipografi, renk) `/lib/pa.css`'ten gelir — `<style>` blogu yazma.
Tek istisna: kit'te karsiligi olmayan bir defalik kucuk duzeltme (`style=""` tek satir).

## Bilesen Rehberi (pa.css + pa.js)

**Yapi**
- `<header class="pa-head">` + `.eyebrow` + `<h1>` + `.sub` + `.meta > .cell > .k/.v` — sayfa basligi
- `<section class="b" data-n="B1"><h2>Baslik <span class="tail">not</span></h2>…</section>` — numarali bolum karti
- `.cols-2` / `.cols-3` / `.grid` + `.card` — kolon/kart yerlesimi; `.card.stripe|stripe-ok|stripe-warn|stripe-err` ust seritli kart
- `<footer class="legend"><span><span class="sw ok"></span> anlami</span>…</footer>` — renk lejanti

**Metin/veri**
- `.badge ok|warn|err|info|muted` — durum rozeti · `.callout ok|warn|err` + `<span class="t">baslik</span>` — vurgu kutusu
- `.verdict ok|warn|err` — tek cumlelik hukum seridi · `dl.kv` — anahtar→deger · `ol.steps` — numarali adimlar
- `.tablewrap > table` — tablo (th otomatik stilli; `td.c` ortala) · `.caption` — tablo alti not
- `pre` + `<span class="hl">` vurgu + `<span class="cmt">` yorum · `.file` — dosya:satir cipi
- `figure.evidence > img + figcaption` — kanit gorseli · `.muted .small .mono .tnum` — yardimcilar

**Web component'ler** (pa.js)
- `<pa-flow steps="A|B|C" tones="|ok|err">` — basit akis zinciri
- `<pa-flow><pa-step k="eyebrow" v="baslik" tone="ok|warn|err|accent" tag="err:buyuk">aciklama</pa-step>…</pa-flow>` — zengin akis
- `<pa-leg idx="Leg 0" from="IST" to="CDG" date="03 Eki" tone="mc|dashed">` — ucus/rota seridi
- `<pa-compare label-before="Once" label-after="Sonra"><div slot="before">…</div><div slot="after">…</div></pa-compare>`
- `<pa-kpi label="Sure" value="1.2s" delta="-40%" tone="ok">` — metrik kutusu
- `<pa-timeline><pa-event n="1" tone="ok" title="baslik" date="…">aciklama</pa-event>…</pa-timeline>` — dikey yol haritasi (`n` yerine `date` verilirse nokta)
- `<canvas data-chart='{"type":"bar","data":{…}}'></canvas>` — Chart.js grafigi (otomatik tema/palet)

**Soru/risk desenleri**
- `.oq > .q > .n` + `.opt` / `.opt.rec` + `.decided > .lbl` — acik soru karti (secenekler + karar)
- `.risk > .desc(strong+span) + .badge…` — risk satiri (aciklama + olasilik/etki rozetleri)

**Ileri seviye**: interaktif sayfa gerekirse `app.jsx` yaz (`<script type="module" src="./app.jsx">`) —
preact otomatik saglanir (`import { html, render, useState } from "/lib/vendor/preact.mjs"`), JSX de
calisir (server transpile eder). Statik analiz sayfalarinda GEREKMEZ.

## Icerik Ilkeleri

- **Gorsel-agir, metin kisa-net**: uzun paragraf yerine sema/tablo/karsilastirma + kisa madde
- Gercek icerik, gercek dosya adlari (`.file` cipiyle `dosya.go:42`), gercek sayilar (`.tnum`)
- Yapisal cihazlar bilgi tasisin: numara = gercek sira, rozet = gercek durum — dekor degil
- Bolum numaralari (`data-n`) korunur — kullanici bolume numarayla atif yapar

## Arsivleme

Is tamamen bitince (teslim/commit sonrasi) konuyu arsivle:

```bash
mv ~/.pa-render/active/<konu-slug> ~/.pa-render/archive/
```

Unutulursa kullanici kendi arayuzunden arsivler/geri alir — senin tek sorumlulugun is kapanisinda
tasimayi denemek (klasor yoksa sessiz gec).
