# Token Efficiency

Subagent ve Workflow ajanlarında **modeli ve effort'u** her zaman bilinçli seç — varsayılana bırakma. Amaç: en küçük **yeterli** model, işi bitiren **en düşük** effort.

## Agent Yazarken (frontmatter)
Yeni agent tanımına **her zaman açık `model:`** yaz. Geçerli değerler: `haiku` / `sonnet` / `opus` / `fable` , tam model ID veya `inherit`.

## Workflow Yazarken (`agent()` çağrıları)

- Her `agent()` çağrısına açık `model` **ve** `effort` yaz:
  `agent(prompt, { label: 'translate:ar', phase: 'Translate', model: 'sonnet', effort: 'low', schema })`
- **`effort` boş bırakılırsa ajan oturumun effort'unu devralır.** `effort: max` ile koşan bir skill'de (örn. `issue-workflow`) bu, mekanik bir ajanın bile `max` düşünmesi demektir — iş yavaşlar, token yanar. Model kadar önemlidir.
- Eşikler:

| İş | model | effort |
|---|---|---|
| Mimari tasarım, imza/şema/sözleşme üretimi, derin verify/judge | `opus` | `high` |
| Sıradan kod yazma, refactor, test yazımı, fix, çeviri | `opus` / `sonnet` | `medium` |
| Mekanik uygulama (rename, taşıma, şablon doldurma) | `sonnet` | `low` |
| Salt-okunur arama / envanter / log tarama | `sonnet` | `low` |

- `xhigh` / `max` yalnızca kullanıcı açıkça isterse — agent kendiliğinden yükseltmez.

## MUTLAK KURAL SUB/AGENT FABLE YASAK
Hiçbir workflow `agent()` çağrısı veya subagent fable ile çalıştırılmaz
Workflow script'inde `opts.model` boş bırakmak ana modeli (fable) devralır → fable oturumunda **her** `agent()` çağrısına açık model yaz; en yükseği `'opus'`.

`Workflow({name: "..."})` ile başlatılan hazır script'ler `agent()` çağrılarında model override taşımaz → fable oturumunda **doğrudan launch YASAK**.
Workflow'un script kaynağını al  Script kopyasındaki **her** `agent()` çağrısına açık `model` yaz (mekanik/finder işleri `'sonnet'`, derin verify/judge `'opus'`).
Script'e erişilemiyorsa veya düzenleme mümkün değilse workflow'u **BAŞLATMA** — durumu kullanıcıya `AskUserQuestion` ile bildir

## Code Review — Tek Kural (MUTLAK, istisnasız)

Agent `/code-review` skill'ini doğrudan çağıramaz. Code-review **her zaman ayrı bir Claude
oturumuna Bash ile devredilir** — model/oturum fark etmeksizin tek yol:

```bash
cd <target_path> && claude --model opus -p '/code-review medium'
```

- `<target_path>` = **çalışma klasörü** (repo kökü veya worktree kökü). `cd` zorunlu — child oturum diff'ini kendi cwd'sinde hesaplar, path'i prompt'a yazmak yetmez (worktree'de yanlış repo review edilir)
- Model **her zaman `--model opus`** — ana oturum modeli ne olursa olsun
- Effort **her zaman `medium`** — agent yükseltmez; `high`+ yalnızca kullanıcı açıkça isterse
- Bash çağrısı **arka planda** koşar (`run_in_background: true`), `timeout: 600000` verilir — asılı review sessizce atlanmasın
- **Recursion guard**: prompt'u `/code-review` ile başlayan oturum zaten review oturumudur — bu kural orada geçerli değildir, skill doğrudan koşar, yeni delegasyon yapmaz
- Code-review için **subagent spawn etme, `Workflow({name: "code-review"})` launch etme** — tek yol yukarıdaki komut
- Çıktı geldiğinde bulgular ham hâliyle alınır, filtrelenmez

### Büyük diff — birden fazla oturuma bölme

Diff büyükse (çok modül / yüzlerce satır — örn. ara commit atmadan yürütülen `issue-workflow` yönetici modu teslimatı) review **3-4 paralel `claude -p` oturumuna bölünebilir**; her oturum ayrı bir dosya kümesine odaklanır:

```bash
cd <target_path> && claude --model opus -p '/code-review medium — sadece <path/alt-dizin> altındaki değişiklikler'
```

- Kural bozulmaz: yol hâlâ **ayrı Claude oturumu**, subagent/Workflow değil
- Kümeler **örtüşmez**; hiçbir değişen dosya kümesiz kalmaz (bölüm listesi `git diff --name-only` üzerinden çıkarılır)
- Hepsi arka planda başlatılır, çıktılar toplanır, bulgular **birleştirilip dedup edilerek** ham hâliyle sunulur
- Bulgu düzeltmesi `Workflow` ile dağıtılabilir (dosya bazında gruplanmış fix ajanları) — bu yasak **review'a** aittir, düzeltmeye değil
