# Analiz Sub-agent Şablonu (pencere × açı fan-out)

Doldur, sonra tek fazda `M × A` sub-agent'ı aynı anda paralel spawn et:
- `DIR` — `fetch_windows.sh` pencere dizini (`$SCR/logwin`).
- `WINDOWS` — `fetch_windows.sh`'in ürettiği pencereler (P1..PM, P1 en yeni) + zaman etiketi (serbest). Örnek: `P1` en yeni 15dk, `P2` 15-30dk önce, `P3` 30-45dk önce, `P4` 45-60dk önce.
- `ANGLES` — 4 standart açı: `hata`, `perf`, `akis`, `hijyen`; brief metinleri `angles.md`'den (HATA / PERF / AKIS / HIJYEN) gömülür. Projeye özel açı (örn "ödeme akışı", "elasticsearch sync") gerekirse ekle.
- Çıktı şeması yok (serbest markdown); istenirse dedup için JSON schema eklenebilir.

## Faz: Analyze

Her `(w, t) ∈ WINDOWS` × her `a ∈ ANGLES` için 1 sub-agent (toplam `M × A`), hepsi paralel; tüm bulgular birlikte toplanır:

| Alan | Değer |
|---|---|
| Etiket | `<w>:<a>` (örn `P1:hata`) |
| Brief | `angles.md` → ilgili açı metni; pencere `w`, zaman etiketi `t`, dosya `<DIR>/<w>.json` doldurulmuş |
| Dönen | serbest markdown bulgu metni |

Her sonucu `{window: w, angle: a, text}` olarak eşle. Hata/boş dönen sub-agent'ı aynı brief'le yeniden spawn et.

## Sonucu toplama (ana agent)

Her bulguyu ayrı `.md`'ye yaz:

```python
import os
out = "<scratchpad>/findings"; os.makedirs(out, exist_ok=True)
for r in results:  # [{window, angle, text}, ...]
    open(f"{out}/{r['window']}_{r['angle']}.md", "w").write(r["text"])
```

Sonra `findings/*.md` ile Adım 3 (dedup + doğrulama).
