# Token Efficiency

Subagent ve Workflow ajanlarında modeli her zaman bilinçli seç — varsayılana bırakma. Amaç: en küçük **yeterli** model.

## Agent Yazarken (frontmatter)
Yeni agent tanımına **her zaman açık `model:`** yaz. Geçerli değerler: `haiku` / `sonnet` / `opus` / `fable` , tam model ID veya `inherit`.
## Workflow Yazarken (`agent()` çağrıları)
- Her `agent()` çağrısına açık `model` yaz: agent(prompt, { label: 'translate:ar', phase: 'Translate', model: 'sonnet', schema })

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
