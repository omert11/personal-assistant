# Analiz Workflow Şablonu (pencere × açı fan-out)

Bu şablonu doldurup tek `Workflow` çağrısı yap. Fan-out birimi **pencere × açı**.
Her `agent()`: `model: 'sonnet'`, `label: '<P>:<açı>'`, `phase: 'Analyze'`.

Doldurman gerekenler:
- `DIR` — `fetch_windows.sh`'in yazdığı pencere dizini (`$SCR/logwin`).
- `WINDOWS` — pencere listesi (`fetch_windows.sh` kaç pencere ürettiyse: P1..PM) + zaman etiketi.
- `ANGLES` — standart 4 açı (aşağıda). Projeye özel açı gerekiyorsa ekle.
- `meta.name` / proje adını isteğe göre güncelle.

Açı prompt metinleri için `angles.md`'ye bak — oradaki metinleri `prompt` fonksiyonlarına göm.

```js
export const meta = {
  name: 'log-triage-analysis',
  description: 'Log pencerelerini açı başına paralel analiz et (hata/perf/akış/hijyen)',
  phases: [{ title: 'Analyze', detail: 'pencere × açı paralel, sonnet' }],
}

// DOLDUR: fetch_windows.sh çıktı dizini
const DIR = '<SCRATCHPAD>/logwin'

// DOLDUR: üretilen pencereler (P1 en yeni). Zaman etiketi serbest.
const WINDOWS = [
  { w: 'P1', t: 'en yeni 15dk' },
  { w: 'P2', t: '15-30dk önce' },
  { w: 'P3', t: '30-45dk önce' },
  { w: 'P4', t: '45-60dk önce' },
]

// 4 standart açı. prompt(w,t,file) → o pencere+açı için tam yönerge.
// Tam prompt metinleri references/angles.md'de — buraya göm.
const ANGLES = [
  { key: 'hata',   prompt: (w,t,file) => `... (angles.md → HATA) ...` },
  { key: 'perf',   prompt: (w,t,file) => `... (angles.md → PERF) ...` },
  { key: 'akis',   prompt: (w,t,file) => `... (angles.md → AKIS) ...` },
  { key: 'hijyen', prompt: (w,t,file) => `... (angles.md → HIJYEN) ...` },
]

phase('Analyze')

// Pencereler paralel, her pencere içinde açılar paralel = M×A agent.
// parallel() bir barrier'dır: tüm bulgular birlikte döner (dedup'tan önce hepsi lazım).
const results = await parallel(
  WINDOWS.flatMap(({ w, t }) =>
    ANGLES.map((a) => () =>
      agent(a.prompt(w, t, `${DIR}/${w}.json`), {
        label: `${w}:${a.key}`,
        phase: 'Analyze',
        model: 'sonnet',
      }).then((text) => ({ window: w, angle: a.key, text }))
    )
  )
)

return results.filter(Boolean)
```

## Sonucu toplama (workflow sonrası, Claude)

Workflow `result` listesi `[{window, angle, text}, ...]` döner ama tool çıktısı **truncate
olabilir** → output dosyasından parse et ve her bulguyu ayrı `.md`'ye yaz:

```python
import json, os
d = json.load(open("<workflow_output_file>"))
out = "<scratchpad>/findings"; os.makedirs(out, exist_ok=True)
for r in d["result"]:
    open(f"{out}/{r['window']}_{r['angle']}.md", "w").write(r["text"])
```

Sonra `findings/*.md`'leri okuyup Adım 3 (dedup + doğrulama) yap.

## Notlar

- `agent()` içinde `schema` kullanmadık (serbest markdown rapor daha esnek). İstersen
  yapılandırılmış çıktı için JSON schema ekleyebilirsin (dedup'ı kolaylaştırır).
- M×A ≤ 16 tipik (4×4). Workflow concurrency cap'i (≈10) altında sırayla akar, sorun değil.
- Projeye özel 5. açı (örn "ödeme akışı", "elasticsearch sync") gerekiyorsa `ANGLES`'a ekle.
