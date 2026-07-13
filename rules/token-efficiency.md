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

Ana oturum modeli Fable ise -> code-review **tek `general-purpose` subagent** ile `model: opus` verilerek çalıştırılır
Ana oturum modeli Fable DEĞİLSE ->  `/code-review medium`
