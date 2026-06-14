---
name: commit
description: Commit oncesi kalite kontrol + teslimat secenekleri (commit, push, PR, branch).
when_to_use: Trigger — "commit", "commit at", "push et", "PR olustur", "branch ac", "degisiklikleri kaydet", "kodu gonder", "/commit". Her kod teslimat/kaydetme isteginde tetiklenir.
disable-model-invocation: false
allowed-tools: Bash(git *), Bash(gh *), Read, Grep, Glob, AskUserQuestion, Task, Workflow
---

# Commit Skill

Kod değişikliklerini commit etmeden önce **toplu analiz** yapar, soruları biriktirir, tek seferde kullanıcıya sunar, onay sonrası teslim eder.

## Temel İlke

**Kullanıcıyı az kes.** Her hata için ayrı soru sorma. Önce tüm analizi yap, bulguları biriktir, sonunda **tek bir AskUserQuestion bloğunda** topla.

## İş Akışı

### 1. Ön Kontrol — Değişiklik Var mı?

```bash
git status --porcelain
```

Boşsa: **"Commit edecek bir şey yok."** deyip çık. Skill sonlanır.

### 2. Branch Tespit

```bash
CURRENT_BRANCH=$(git branch --show-current)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
IS_MAIN=$([ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ] && echo true || echo false)
IS_WORKTREE=$([ -f .git ] && echo true || echo false)
```

Bu bilgiyi son adımdaki teslimat seçenekleri için kullan.

### 3. Toplu Analiz (sıralı, sessiz)

Her adımda bulguları **belleğe topla**, bitince hepsini birden sun.

#### 3a. Değişiklikleri Çıkar
```bash
git diff --stat
git diff --cached --stat  # staged varsa
git diff
```

#### 3b. Code Review — ZORUNLU (kod değişikliği varsa)

**Kural kesin**: `git diff --stat` çıktısında herhangi bir **kod dosyası** (`.py`, `.js`, `.ts`, `.tsx`, `.jsx`, `.go`, `.rs`, `.java`, `.kt`, `.swift`, `.dart`, `.rb`, `.php`, `.c`, `.cpp`, `.cs`, `.sh`, `.vue`, `.svelte`) değişmişse review **mutlaka** çalıştırılır.

- **Atlanamaz**, **ertelenemez**, **koşula bağlanamaz**.
- Kullanıcı "commit at hadi", "hızlıca commit", "direkt commit" dese bile önce review çalışır.
- Sadece **non-kod dosyaları** (`.md`, `.json`, `.yml`, `.txt`, asset'ler) değişmişse atlanabilir.
- Skip sadece kullanıcı **açıkça** "code-review atla" / "skip code-review" / "code-review çalıştırma" derse mümkün — bu durumda bulgu olarak "kullanıcı explicit skip istedi" diye işaretle.

**Mekanizma effort'a göre seçilir** (effort seçimi aşağıda):

- `low` → **Inline review**: tek diff geçişi, subagent yok (aşağıda "Low Effort — Inline Review").
- `medium` ve üzeri → **Review Workflow**: `Workflow` tool'u ile aşama aşama (Scope → Find → Verify → Sweep → Report) çalışır, her fazın ajanına effort'a göre açık model atanır (aşağıda "Review Workflow"). Built-in `/code-review` skill'i ÇAĞRILMAZ — onun workflow'u model belirtmediği için tüm ajanlar pahalı ana oturum modelini devralıyor; bu script aynı yapıyı kalibre edilmiş modellerle çalıştırır.

##### Dürüst Review — KESKİN KURAL

**Kod bir kere review edilir, bir daha edilmeyecek.** Bu yüzden review **dürüst, eksiksiz ve kolaya kaçmadan** yapılmalı. Bulunan hiçbir bulgu **görmezden gelinemez** veya **atlanması gerekli görülemez**.

**Yasaklar:**
- Bulguları "küçük", "önemsiz", "stil meselesi" diye **filtrelemek yasak** — tüm bulgular Soru 1'e ham haliyle dahil edilir.
- Review effort'unu **işten bağımsız seçmek yasak** — effort değişikliğin karmaşıklığına göre kalibre edilir (aşağıdaki "Effort Seçimi"). Gereksiz yüksek effort de, kolaya kaçan düşük effort de hatadır.
- Review'i **hızlandırmak için kısa kesmek yasak** — workflow background çalışır, task-notification ile sonucu bekle; "muhtemelen sorun yok" diye atlama. Beklerken working tree'de çakışacak iş yapma.
- Bulguyu **kullanıcıya sunmadan elemek yasak** — false positive olduğunu düşünsen bile bulguyu listele, kullanıcı karar versin.
- Bulguları **özetlerken yumuşatmak yasak** — "minor issue" yerine review'in dediği şiddet seviyesini aynen aktar.
- "Zaten test geçiyor" / "küçük değişiklik" / "trivial" gibi gerekçelerle review **atlanamaz**.
- Kullanıcı baskı yapsa bile ("hadi hızlı geç", "kabul et gitsin") bulguları **gizlemek yasak** — kullanıcı görsün, kullanıcı karar versin.

**Pozitif gereklilikler:**
- Review çıktısındaki **her bulgu** Soru 1'in `question` metnine **şiddet + dosya:satır + kısa açıklama** ile dahil edilir.
- Bulgu sayısı >5 ise hepsini listele, "ilk 5 + ..." şeklinde özetleme.
- Review crash / timeout olursa **sessizce geçme** — kullanıcıya raporla, tekrar dene veya açıkça skip onayı al.
- Review'in `high` effort'la verdiği "uncertain" bulgular bile listelenir — kullanıcı false positive olduğuna karar verebilir, sen değil.

##### Effort Seçimi — Karmaşıklığa Göre Kalibre Et

Effort, **yapılan işin karmaşıklığına** göre seçilir — gereksiz yüksek effort verme (zaman/token israfı), karmaşık işte düşük effort'a kaçma (kaçan bug). `git diff --stat` + diff içeriğine bakıp karar ver. Effort yükseldikçe faz modelleri de güçlenir:

| Effort | Ne zaman | Mekanizma | Find | Verify | Report |
|---|---|---|---|---|---|
| `low` | Tek-birkaç satırlık trivial değişiklik: typo, rename, sabit/string güncelleme, import düzeltme | Inline (workflow yok) | — | — | — |
| `medium` (varsayılan) | Sıradan feature/fix: birkaç dosya, sınırlı mantık değişikliği | Workflow | opus | sonnet | sonnet |
| `high` | Karmaşık mantık, çok dosyaya yayılan değişiklik, güvenlik-kritik kod, data-mutating işlem (migration, ödeme, silme), concurrency/race riski | Workflow | opus | opus | sonnet |
| `xhigh`/`max` | Sadece kullanıcı açıkça isterse — skill kendi inisiyatifiyle seçmez | Workflow + Sweep | inherit (ana model) | opus | opus |

- Scope fazı her seviyede `sonnet` (diff + konvansiyon özeti) ve aynı zamanda **karmaşıklığı kendisi tespit eder** (`trivial`/`normal`/`complex` + `linesChanged`). Effort'u dışarıdan verdiğin model seviyesi (finder/verifier modelleri) belirlerken, **kaç agent spawn edileceğini** scope'un bu kararı belirler — alttaki "Agent Sayısı" notuna bak.
- Kararsızsan bir üst seviyeyi seç (eksik review > fazla review maliyetinden pahalı).
- Effort seçimi review'in **dürüstlüğünü** etkilemez: seçilen seviyenin verdiği TÜM bulgular yine ham haliyle sunulur.

##### Agent Sayısı — Scope Karmaşıklığına Göre Gruplama

Find ve Verify fazları her açıyı/adayı ayrı agent'a vermez; **scope'un `complexity` + `linesChanged` kararına göre işleri gruplar** — küçük/basit diff'te az agent, büyük/riskli diff'te tam izolasyon:

| Scope kararı | Find: açı/agent | Verify: aday/agent | Mantık |
|---|---|---|---|
| `complex` **veya** >400 satır | 1 | 1 | Her lens/aday izole — geniş blast radius, riskli kod |
| `normal` **veya** >80 satır | 2 | 2 | Lens'leri/adayları ikişerle topla |
| `trivial` / küçük diff | 3 | 3 | Üçerli batch — agent sayısını minimuma indir |

Bir finder agent'ı taşıdığı her lens'i ayrı ayrı tam uygular (biri diğerini boğmaz); aday üst sınırı `perAngle × grup boyutu` olur. Bir verifier agent'ı grubundaki her adayı bağımsız değerlendirip indeksli verdict döndürür. Böylece 9 açılık bir review trivial diff'te 3 finder agent'ıyla, complex diff'te 9 finder agent'ıyla çalışır — kalite aynı, maliyet diff'e göre ölçeklenir.

##### Low Effort — Inline Review

Workflow açılmaz. Tek tool çağrısıyla diff'i oku (`git diff @{upstream}...HEAD; git diff HEAD`), hunk'tan görünen runtime-correctness buglarını işaretle: ters koşul, off-by-one, null/undefined deref, kaldırılan guard, falsy-zero, eksik `await`, yanlış-değişken copy-paste, yutulan hata. Ayrıca diff bağlamında görünen duplicate helper ve geride kalan dead code. Stil, isimlendirme, perf, eksik test FLAG EDİLMEZ. En fazla 4 bulgu, en kritik önce: `dosya:satır — sorun + somut hata senaryosu`. Hiçbiri yoksa "(none)".

##### Review Workflow (medium ve üzeri)

`Workflow` tool'unu aşağıdaki script ile çağır; `args` olarak `"<effort> <varsa hedef/ek talimat>"` geçir (örn. `"high sadece payment/ dizinine odaklan"`). Workflow background çalışır — tamamlanma bildirimini bekle, dönen `report` + `findings` çıktısını bulgu olarak Soru 1'e ham haliyle taşı.

```js
export const meta = {
  name: 'commit-review',
  description: 'Find/Verify/Sweep/Report code review with per-phase calibrated models',
  phases: [
    { title: 'Scope', detail: 'diff + changed files + conventions' },
    { title: 'Find', detail: 'parallel finder angles' },
    { title: 'Verify', detail: 'one verdict per candidate' },
    { title: 'Report', detail: 'ranked findings synthesis' },
    // Sweep is intentionally absent: it only runs at xhigh/max and gets its own progress group then
  ],
}

// Effort ladder — models strengthen as effort rises (null = inherit main-loop model)
const LEVELS = {
  medium: { correctness: 3, perAngle: 6, maxFindings: 8,  sweep: false, recall: false, finder: 'opus', verifier: 'sonnet', report: 'sonnet' },
  high:   { correctness: 3, perAngle: 6, maxFindings: 10, sweep: false, recall: true,  finder: 'opus', verifier: 'opus',   report: 'sonnet' },
  xhigh:  { correctness: 5, perAngle: 8, maxFindings: 15, sweep: true,  recall: true,  finder: null,   verifier: 'opus',   report: 'opus' },
  max:    { correctness: 5, perAngle: 8, maxFindings: 15, sweep: true,  recall: true,  finder: null,   verifier: 'opus',   report: 'opus' },
}
const MAX_VERIFY = 25
const RAW = (typeof args === 'string' ? args : '').trim()
const FIRST = RAW.split(/\s+/)[0] || ''
const LEVEL = Object.prototype.hasOwnProperty.call(LEVELS, FIRST) ? FIRST : 'medium'
const TARGET = LEVEL === FIRST ? RAW.slice(FIRST.length).trim() : RAW
const P = LEVELS[LEVEL]
const mdl = (m) => (m ? { model: m } : {})

const CORRECTNESS = [
  { key: 'diff-scan', text: 'Read every hunk line by line, then the enclosing function of each hunk. For every line ask: what input, state, timing, or platform makes it wrong? Inverted conditions, off-by-one, null/undefined deref, missing await, falsy-zero checks, wrong-variable copy-paste, errors swallowed in catch.' },
  { key: 'removed-behavior', text: 'For every line the diff deletes or replaces, name the invariant it enforced and find where the new code re-establishes it. A removed guard, dropped error path, narrowed validation, or deleted covering test is a candidate.' },
  { key: 'cross-file', text: 'For each changed function, Grep its callers and callees. Flag call sites broken by a new precondition, changed return shape, new exception, or timing/ordering dependency.' },
  { key: 'lang-pitfalls', text: "Scan for the diff language's classic pitfalls: JS falsy-zero / == coercion / closure-captured loop var; Python mutable default args / late-binding closures; Go nil-map write / range-var capture; SQL injection; timezone/DST drift; float equality." },
  { key: 'wrapper-proxy', text: 'If the diff adds or modifies a wrapper type (cache, proxy, decorator, adapter): check every method routes through the wrapped instance (not back through a registry/session/global) and that all caller-used methods are forwarded.' },
]
const CLEANUP = [
  { key: 'reuse', text: 'Flag new code that re-implements something the codebase already has. Grep shared/utility modules and files adjacent to the change; name the existing helper to call instead.' },
  { key: 'simplify', text: 'Flag unnecessary complexity the diff adds: redundant or derivable state, copy-paste with slight variation, deep nesting, dead code left behind. Name the simpler form.' },
  { key: 'efficiency', text: 'Flag wasted work the diff introduces: redundant computation or repeated I/O, independent operations run sequentially, blocking work on startup or hot paths. Name the cheaper alternative.' },
  { key: 'altitude', text: 'Check each change sits at the right depth, not as a fragile bandaid: special cases layered on shared infrastructure signal the fix is not deep enough — prefer generalizing the mechanism.' },
]
const ANGLES = CORRECTNESS.slice(0, P.correctness).concat(CLEANUP)

const SCOPE_SCHEMA = {
  type: 'object', required: ['diffCommand', 'files', 'summary', 'linesChanged', 'complexity'],
  properties: {
    diffCommand: { type: 'string' },
    files: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    conventions: { type: 'string' },
    linesChanged: { type: 'number', description: 'total added+removed lines across the diff' },
    complexity: { enum: ['trivial', 'normal', 'complex'], description: 'reviewer-facing risk: trivial=mechanical/string/import, normal=ordinary feature/fix, complex=intricate logic, multi-file blast radius, security/data-mutating, concurrency' },
    complexityReason: { type: 'string', description: 'one line justifying the complexity rating' },
  },
}
const CANDIDATES_SCHEMA = {
  type: 'object', required: ['candidates'],
  properties: { candidates: { type: 'array', items: {
    type: 'object', required: ['file', 'summary', 'failure_scenario'],
    properties: {
      file: { type: 'string' }, line: { type: 'number' },
      summary: { type: 'string' }, failure_scenario: { type: 'string' },
    },
  } } },
}
const VERDICT_SCHEMA = {
  type: 'object', required: ['verdicts'],
  properties: { verdicts: { type: 'array', items: {
    type: 'object', required: ['index', 'verdict', 'evidence'],
    properties: {
      index: { type: 'number', description: 'the candidate number this verdict is for' },
      verdict: { enum: ['CONFIRMED', 'PLAUSIBLE', 'REFUTED'] },
      evidence: { type: 'string' },
    },
  } } },
}

phase('Scope')
const scope = await agent(
  'Establish the scope of a code review AND judge its complexity — your judgement drives how many agents the rest of the review spawns, so weigh it honestly.\n' +
  (TARGET ? 'Review target / instructions (verbatim): "' + TARGET + '". Honor any scope restriction when building the diff command.\n' : '') +
  "1. Build and run the diff command: prefer 'git diff @{upstream}...HEAD' (fallback 'git diff main...HEAD' / 'git diff HEAD~1'); also include 'git diff HEAD' if there are uncommitted changes.\n" +
  '2. List the changed files.\n' +
  '3. Summarize what changed in one paragraph.\n' +
  '4. Read CLAUDE.md files relevant to the changed files and note reviewer-relevant conventions.\n' +
  '5. Count linesChanged (added+removed across the whole diff).\n' +
  '6. Rate complexity by what the change actually does, not just its size:\n' +
  '   - trivial: mechanical edits — typo, rename, string/constant update, import fix, formatting; no logic to reason about.\n' +
  '   - normal: an ordinary feature or fix — bounded logic across a few files, nothing security- or data-critical.\n' +
  '   - complex: intricate control flow, change rippling across many files/call sites, security-sensitive, data-mutating (migration, payment, delete), or concurrency/ordering risk. A small diff can still be complex.\n' +
  '   Give complexityReason in one line.\n' +
  'Return diffCommand exactly as a reviewer should run it. Structured output only.',
  { label: 'scope', model: 'sonnet', schema: SCOPE_SCHEMA }
)
if (!scope) return { level: LEVEL, findings: [], report: 'Scope agent failed — review could not run.' }
if (!scope.files || scope.files.length === 0) return { level: LEVEL, findings: [], report: 'No changes found to review.' }

// Scope's complexity judgement + line count decide how many angles each finder agent carries.
// Goal: fewer agents on small/simple diffs, one-angle-per-agent only when the change earns it.
const lines = scope.linesChanged || 0
const cx = scope.complexity || 'normal'
let anglesPerAgent
if (cx === 'complex' || lines > 400) anglesPerAgent = 1          // big blast radius / risky → isolate each lens
else if (cx === 'normal' || lines > 80) anglesPerAgent = 2       // ordinary change → pair lenses
else anglesPerAgent = 3                                          // trivial / tiny diff → batch lenses
const chunk = (arr, n) => arr.reduce((acc, x, i) => { if (i % n === 0) acc.push([]); acc[acc.length - 1].push(x); return acc }, [])
const angleGroups = chunk(ANGLES, anglesPerAgent)
log(LEVEL + ' review: ' + scope.files.length + ' files, ~' + lines + ' lines, ' + cx +
    ' → ' + ANGLES.length + ' angles in ' + angleGroups.length + ' finder agent(s) (' + anglesPerAgent + '/agent)' +
    ', finder=' + (P.finder || 'inherit') + ', verifier=' + P.verifier)

const SCOPE_BLOCK =
  '## Review scope\nDiff command: ' + scope.diffCommand + '\nChanged files:\n' +
  scope.files.map(f => '- ' + f).join('\n') +
  '\n\n## What changed\n' + scope.summary +
  '\n\n## Conventions\n' + (scope.conventions || '(none)') +
  (TARGET ? '\n\n## User instructions (verbatim)\n' + TARGET + '\nHonor scope restrictions; do not surface findings the instructions ask to skip.' : '')

phase('Find')
const found = await parallel(angleGroups.map(group => () => {
  const lensBlock = group.map((a, i) =>
    'Lens ' + (i + 1) + ' — ' + a.key + ':\n' + a.text).join('\n\n')
  const label = 'find:' + group.map(a => a.key).join('+')
  return agent('## Code-review finder\n\n' + SCOPE_BLOCK +
    '\n\nRun the diff command above and review it through EACH of the following ' + group.length +
    ' lens(es). Apply every lens fully — do not let one lens crowd out another:\n\n' + lensBlock +
    '\n\nAcross all lenses combined, surface up to ' + P.perAngle +
    ' candidates total (a fixed budget regardless of how many lenses this agent carries — report only the strongest), each with file, line, a one-line summary, and a concrete failure_scenario (for cleanup lenses, state the concrete cost instead of a crash). Pass every candidate with a nameable failure scenario through — do not silently drop half-believed candidates; an independent verifier judges them next. Empty list if nothing qualifies. Structured output only.',
    { label, phase: 'Find', schema: CANDIDATES_SCHEMA, ...mdl(P.finder) })
}))
// barrier justified: dedup across ALL finders before expensive verification
const dedup = new Set()
let candidates = found.filter(Boolean).flatMap(r => r.candidates).filter(c => {
  const k = c.file + ':' + (c.line ?? '?')
  if (dedup.has(k)) return false
  dedup.add(k)
  return true
})
if (candidates.length > MAX_VERIFY) {
  log('capping verify at ' + MAX_VERIFY + ' of ' + candidates.length + ' candidates')
  candidates = candidates.slice(0, MAX_VERIFY)
}
// sweep dedup keys come from VERIFIED candidates only — capped-out ones may resurface in sweep
const seen = new Set(candidates.map(c => c.file + ':' + (c.line ?? '?')))
log(candidates.length + ' unique candidates to verify')

const RECALL_NOTE = P.recall
  ? '\nRecall-biased: do NOT refute for being "speculative" when the trigger state is realistic (races, rare-but-reachable paths, falsy-zero, boundary off-by-one). REFUTED only when constructible from the code: quote the line that proves it, show the type/invariant, or cite the guard in this diff.'
  : ''
// Verify grouping mirrors Find: complex/risky diffs get one candidate per verifier (max scrutiny),
// simpler diffs batch several candidates into one verifier agent to cut agent count.
const candsPerVerifier = (cx === 'complex' || lines > 400) ? 1 : (cx === 'normal' || lines > 80) ? 2 : 3
const verifyGroup = (group) => {
  const block = group.map((c, i) =>
    'Candidate ' + (i + 1) + ' — File: ' + c.file + (c.line != null ? ':' + c.line : '') +
    '\n  Summary: ' + c.summary + '\n  Failure scenario: ' + c.failure_scenario).join('\n\n')
  return agent('## Code-review verifier\n\n' + SCOPE_BLOCK +
    '\n\nRun the diff command, read the relevant file(s), and judge EACH candidate below independently. ' +
    'Return one verdict per candidate, tagged with its candidate number as `index`:\n\n' + block +
    '\n\nFor each, return exactly one verdict:\n' +
    '- CONFIRMED — you can name the inputs/state that trigger it and the wrong output/crash. Quote the line.\n' +
    '- PLAUSIBLE — mechanism is real, trigger uncertain. State what would confirm it.\n' +
    '- REFUTED — factually wrong or guarded elsewhere. Quote the line that proves it.' +
    RECALL_NOTE + '\nStructured output only. Each evidence must quote or cite the relevant line(s).',
    { label: 'verify:' + group.map(c => c.file).join('+'), phase: 'Verify', schema: VERDICT_SCHEMA, ...mdl(P.verifier) })
    .then(r => {
      const verdicts = (r && r.verdicts) || []
      // Match each candidate ONLY by its 1-based index — never positional fallback:
      // a misordered/short/duplicate-index response could otherwise stamp candidate B's
      // verdict + evidence onto candidate A (wrong file/line) or revive a REFUTED one.
      return group.map((c, i) => {
        const matches = verdicts.filter(x => x.index === i + 1)
        const v = matches.length === 1 ? matches[0] : null
        if (!v) {
          // Verdict missing or ambiguous — surface as PLAUSIBLE rather than drop or mis-attribute.
          return { ...c, verdict: 'PLAUSIBLE', evidence: 'Verifier returned no clear verdict for this candidate; review manually.' }
        }
        return v.verdict !== 'REFUTED' ? { ...c, verdict: v.verdict, evidence: v.evidence } : null
      })
    })
}

phase('Verify')
let confirmed = (await parallel(chunk(candidates, candsPerVerifier).map(g => () => verifyGroup(g)))).flat().filter(Boolean)

if (P.sweep) {
  phase('Sweep')
  const sweep = await agent('## Code-review sweep\n\n' + SCOPE_BLOCK +
    '\n\n## Already-verified findings\n' +
    (confirmed.map(f => '- ' + f.file + (f.line != null ? ':' + f.line : '') + ' — ' + f.summary).join('\n') || '(none)') +
    '\n\nRe-read the diff and enclosing functions looking ONLY for defects not already listed: moved/extracted code that dropped a guard or anchor, second-tier footguns (default evaluated once, lock-scope shrink, side-effecting predicates), setup/teardown asymmetry in tests, flipped config defaults. Up to 8 new candidates; empty if nothing new — do not pad. Structured output only.',
    { label: 'sweep', schema: CANDIDATES_SCHEMA, ...mdl(P.finder) })
  const fresh = (sweep ? sweep.candidates : []).filter(c => !seen.has(c.file + ':' + (c.line ?? '?')))
  if (fresh.length) {
    log('sweep found ' + fresh.length + ' new candidates')
    confirmed = confirmed.concat((await parallel(chunk(fresh, candsPerVerifier).map(g => () => verifyGroup(g)))).flat().filter(Boolean))
  }
}

phase('Report')
const report = confirmed.length === 0
  ? 'No findings survived verification.'
  : await agent('## Code-review report\n\nSynthesize the verified findings below into a review report. Rank most-severe first; correctness bugs always outrank cleanup findings. Keep at most ' + P.maxFindings + ' (cut least-severe cleanup first). For each finding write: `file:line — [verdict] summary`, then the failure scenario on the next line. End with a one-paragraph overall assessment.\n\n' + JSON.stringify(confirmed, null, 2),
      { label: 'report', model: P.report })

return {
  level: LEVEL,
  stats: { angles: ANGLES.length, candidates: candidates.length, verified: confirmed.length },
  findings: confirmed,
  report,
}
```

Çıktıyı bulgu olarak topla. Review değişiklik önerdiyse Soru 1'e dahil et.

#### 3c. Test Kontrolü
- Değişen dosyaların test'i var mı? (`*.test.*`, `*_test.*`, `tests/`, `__tests__/`)
- Yoksa **bulgu olarak işaretle** (sormak için bekle)

#### 3d. Rules Uyum Kontrolü

`~/.claude/rules/` altındaki **tüm** dosyaları + **proje `CLAUDE.md` ve `CLAUDE.local.md`'sini** dinamik tara:

```bash
ls ~/.claude/rules/*.md
[ -f CLAUDE.md ] && echo CLAUDE.md              # projeye özgü kamuya açık kurallar
[ -f CLAUDE.local.md ] && echo CLAUDE.local.md  # projeye özgü private kurallar
```

Her dosyayı oku, değişen kodla alakalı kuralları bul. Sabit liste tutma — yeni rule eklendiğinde otomatik kapsansın. **Proje `CLAUDE.md` ve `CLAUDE.local.md`'sindeki kurallar da bağlayıcıdır** (örn. versiyon bump, projeye özgü senkron kuralları, frontmatter konvansiyonları) — bu yüzden global rules'a gömülemeyecek proje-spesifik commit kuralları burada yakalanır. Örnek alaka eşlemeleri:

- Kod dosyası değişti → `coding.md`, `ask-first.md`, dil-spesifik (`python.md`, `django.md`)
- `.po` dosyası → `django.md` (F7 çeviri)
- Shell/CI script → `cli-tools.md`, `soloterm.md`
- Frontend test → `browser-testing.md`
- Obsidian/vault dosyaları → `obsidian.md`, `learnings.md`
- Yapılandırma (CLAUDE.md/local) → `init.md`
- Workflow/agent değişiklikleri → `workflow.md`
- Sunucu/production credential → `production.md`, `b2c-booking-log.md`
- Genel her commit için → `before-commit.md` (zaten bu skill'in kapsamı)

İhlal varsa bulgu olarak topla. Alakasız rule dosyası varsa atla.

#### 3e. Vikunja Görev Bağlantısı
`CLAUDE.local.md`'de Vikunja proje ID varsa:
```
vikunja-cli task list --filter "done = false" --json ile aktif görevleri getir
```
Yapılan değişikliklerle uyuşan bir görev var mı tespit et:
- **Var**: ID'sini sakla (sonra kapat)
- **Yok**: bulgu olarak işaretle (yeni görev önerisi için)

#### 3f. Obsidian Kayıt İhtiyacı
`CLAUDE.local.md`'de `Obsidian Folder` varsa bu commit'te kaydedilmesi kayda değer bir şey var mı tespit et (dar kriter — kanonik tanım: `agents/obsidian-writer.md` append guard):
- Yeni credential/sunucu/endpoint bilgisi
- Çözülen non-trivial bug + çözümü
- Kalıcı mimari/teknik karar

Repo/CLAUDE.md/vault'ta zaten yazılı bilgi veya genel oturum özeti kayda değer sayılmaz; şüphedeysen önerme.

Varsa bulgu olarak işaretle. Yoksa sessiz geç.

### 4. Toplu Soru Bloğu — Olabildiğince Tek Seferde

**Temel Kural**: Tüm bulgular + teslimat seçimi **önceden toplu sorulur**. Kesik kesik soru yasak. Max 4 soru/blok; 4'ten fazla soru varsa art arda (2. faz) blok.

**Commit mesajı otomatik türetilir — SORULMAZ.** Conventional commit format (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`) tercih edilir. Diff özeti + branch ismi + değişen dosyalardan türet.

#### Faz 1 — Ana Blok (≤4 soru)

Aktif olanları (koşul sağlanan) sıraya koy, ilk 4'ünü tek blokta sor:

**S1 — Tespit Edilen Sorunlar** (varsa)
- header: "Sorunlar"
- question: "Şu bulgular var: [review: X, rules ihlal: Z]. Düzelteyim mi?"
- options: ["Evet, düzelt" (Recommended), "Sadece kritikleri düzelt", "Geçiştir, commit et"]

**S2 — Test Eksikse** (3c bulgusu varsa)
- header: "Test"
- question: "Test yazılmamış: [dosyalar]. Ne yapalım?"
- options: ["Test yaz", "Testsiz devam et"]

**S3 — Vikunja** (proje ID varsa)
- Görev varsa: header "Vikunja", question "Görev #X'i kapatayım mı?", options ["Evet kapat (DONE)", "Açık bırak"]
- Görev yoksa: question "Bu değişiklik için Vikunja'da görev oluşturayım mı (DONE olarak)?", options ["Evet", "Hayır"]

**S4 — Teslimat** (branch'e göre değişir)

Ana branch'te (main/master):
- header: "Teslimat"
- question: "Commit sonrası ne yapayım?"
- options:
  - "PR + Merge + Clean" (Recommended) — branch aç, push, PR, merge, cleanup
  - "Branch + PR" — branch aç, push, PR (merge etme)
  - "Push et" — direkt `git push` (risky)
  - "Sadece commit" — local bırak

Feature branch'te:
- header: "Teslimat"
- question: "Commit sonrası ne yapayım?"
- options:
  - "PR + Merge + Clean" (Recommended) — push, PR, merge, cleanup
  - "PR oluştur" — push, PR (merge etme)
  - "Push et" — sadece `git push`
  - "Sadece commit" — local bırak

#### Faz 2 — Ek Blok (koşullu, ≤4 soru)

Faz 1'de yer kalmayan veya koşullu sorular:

**S5 — Obsidian** (3f bulgusu varsa)
- header: "Obsidian"
- question: "Bu commit'te kayda değer bilgi var. Obsidian klasörüne not ekleyeyim mi?"
- options: ["Evet, obsidian-writer ile ekle", "Hayır, geç"]
- Evet seçilirse commit sonrası `Task` ile `obsidian-writer MODE: append` çağır.

**S6 — Worktree** (worktree'deyse)
- header: "Worktree"
- question: "Worktree'desin. `worktree` skill'i çalıştırayım mı (PR + merge + cleanup)?"
- options: ["Evet, worktree skill çalıştır", "Hayır, sadece commit"]

**Kural**: Faz 2 sadece gerçekten ek soru varsa tetiklenir. Yoksa Faz 1 sonrası direkt commit + teslimat.

Sorunlar düzeltildikten sonra **son bir analiz** yap: "Atladığım bir şey var mı?" Yeni bulgu varsa tek ek blok ile sor.

### 5. Commit

```bash
git add <ilgili-dosyalar>  # asla `git add -A` veya `git add .` kullanma (sensitive dosya riski)
```

```bash
git commit -m "$(cat <<'EOF'
<commit mesajı>

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

**Co-Authored-By her zaman eklenir.**

### 6. Pre-commit Hook Fail Olursa

1. Hata mesajını oku
2. Otomatik düzelt (formatter, linter, vb.)
3. Yeniden stage + commit dene
4. Hâlâ fail ise kullanıcıya göster: "Şu hata var, ne yapalım?"

**Asla `--no-verify` kullanma.**

### 7. Teslimat Uygulama

Teslimat seçimi **Faz 1 S4**'te alındı. Commit sonrası seçime göre uygula:
- "PR + Merge + Clean" → branch aç (gerekirse), push, PR, merge, cleanup
- "Branch + PR" / "PR oluştur" → branch aç (gerekirse), push, PR
- "Push et" → `git push`
- "Sadece commit" → hiçbir şey yapma

### 8. Branch İsmi

Yeni branch açma seçildiğinde:
- Format: `feat/<kebab-case-konu>` veya `fix/`, `chore/`, `docs/` prefix'leriyle
- Commit mesajının ana konusundan otomatik türet
- **Kullanıcıya sorma**, direkt aç

```bash
BRANCH_NAME="feat/$(echo "$CONU" | tr '[:upper:]' '[:lower:]' | tr -s ' _' '-' | sed 's/[^a-z0-9-]//g')"
git checkout -b "$BRANCH_NAME"
```

### 9. PR Oluşturma

```bash
gh pr create --title "<commit subject>" --body "$(cat <<'EOF'
## Summary
<1-3 madde>

## Test plan
- [ ] <test maddeleri>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 10. Vikunja Kapatma

Soru 3'te "Evet kapat" seçildiyse (`--done` değer zorunlu: `true`/`false`):
```
vikunja-cli --json task update <id> --done true
```

Görev yoksa ve "Evet" seçildiyse (create pozisyonel argüman alır, `--done` flag'i YOK — önce create, sonra update):
```
vikunja-cli --json task create <pid> "<özet>" --description "<detay>"
vikunja-cli --json task update <yeni-id> --done true
```

## Kritik Kurallar

- **Asla onay almadan commit atma**
- **Asla `git add -A` veya `git add .`** — dosyaları tek tek seç
- **Asla `--no-verify`** — hook fail ise düzelt
- **Asla `--amend`** — yeni commit oluştur (önceki yanlış olabilir)
- **Asla `git push --force` ana branch'e** (uyar)
- **Co-Authored-By her commit'te**
- Conventional commit **tercih edilir** ama zorlama
- Türkçe iletişim, İngilizce commit mesajı

## İlişkili Dosyalar

- `~/.claude/rules/before-commit.md` — bu skill'in temel kuralları
- `~/.claude/rules/coding.md` — kod kalite kuralları
- `~/.claude/rules/ask-first.md` — AskUserQuestion kullanım kuralları
- `worktree` skill (varsa) — worktree teslim akışı
