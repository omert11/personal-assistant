---
name: commit
description: Commit oncesi kalite kontrol + teslimat secenekleri (commit, push, PR, branch).
when_to_use: Trigger — "commit", "commit at", "push et", "PR olustur", "branch ac", "degisiklikleri kaydet", "kodu gonder", "/commit". Her kod teslimat/kaydetme isteginde tetiklenir.
disable-model-invocation: false
allowed-tools: Bash(git *), Bash(gh *), Bash(plane-cli *), Read, Grep, Glob, AskUserQuestion, Task
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

Review **built-in `/code-review` skill'i** ile çalıştırılır — `code-review` skill'ini effort seviyesiyle çağır (örn. `/code-review high`; effort seçimi aşağıda "Effort Seçimi"). Skill'in tüm akışını ve verdiği bulguları olduğu gibi al; kendi workflow/subagent kurma.

##### Dürüst Review — KESKİN KURAL

**Kod bir kere review edilir, bir daha edilmeyecek.** Bu yüzden review **dürüst, eksiksiz ve kolaya kaçmadan** yapılmalı. Bulunan hiçbir bulgu **görmezden gelinemez** veya **atlanması gerekli görülemez**.

**Yasaklar:**
- Bulguları "küçük", "önemsiz", "stil meselesi" diye **filtrelemek yasak** — tüm bulgular Soru 1'e ham haliyle dahil edilir.
- Review effort'unu **işten bağımsız seçmek yasak** — effort değişikliğin karmaşıklığına göre kalibre edilir (aşağıdaki "Effort Seçimi"). Gereksiz yüksek effort de, kolaya kaçan düşük effort de hatadır.
- Review'i **hızlandırmak için kısa kesmek yasak** — diff büyükse skill'in tam çalışmasını bekle, "muhtemelen sorun yok" diye atlama.
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

Effort, **yapılan işin karmaşıklığına** göre seçilir — gereksiz yüksek effort verme (zaman/token israfı), karmaşık işte düşük effort'a kaçma (kaçan bug). `git diff --stat` + diff içeriğine bakıp karar ver, `code-review` skill'ini seçtiğin seviyeyle çağır. Varsayılan eğilim **küçük/lokal diff'te düşük effort** yönünde; yükseltme için diff'in somut bir üst-kriteri karşılaması gerekir:

| Effort | Ne zaman |
|---|---|
| `low` (küçük diff varsayılanı) | Tek-birkaç dosyada lokal, dar kapsamlı değişiklik: typo/rename/import, sabit/string güncelleme, küçük mantık eklemesi/düzeltmesi, test/docs/config değişikliği — kritik olmayan ve yan etkisi sınırlı işler |
| `medium` | Sıradan feature/fix: birden çok dosyaya yayılan, gerçek iş mantığı taşıyan orta ölçekli değişiklik |
| `high` | Karmaşık mantık, geniş yüzeye yayılan değişiklik, güvenlik-kritik kod, data-mutating işlem (migration, ödeme, silme), concurrency/race riski |
| `xhigh`/`max` | Sadece kullanıcı açıkça isterse — skill kendi inisiyatifiyle seçmez |

- **Küçük/lokal diff'lerde `low`'da kal** — birkaç satır veya tek bir dar değişiklik için `medium`'a yükseltme; gereksiz yüksek effort zaman/token israfıdır.
- Yukarı seviyeyi ancak değişiklik **gerçekten** üst kriterlerden birine giriyorsa seç (data-mutating, güvenlik, geniş yüzey, karmaşık mantık) — "ne olur ne olmaz" gerekçesiyle değil.
- Effort seçimi review'in **dürüstlüğünü** etkilemez: seçilen seviyenin verdiği TÜM bulgular yine ham haliyle sunulur.

##### Çağrı

`code-review` skill'ini çalıştır; effort'u yukarıdaki tabloya göre geçir (örn. `/code-review high`). Belirli bir dizine/dosyaya odaklanılması gerekiyorsa skill'e bunu belirt. Skill'in döndürdüğü bulguların hepsini ham haliyle Soru 1'e taşı.

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

#### 3e. Plane Issue Bağlantısı (opsiyonel)
`CLAUDE.local.md`'de **Plane proje (UUID) tanımlıysa** (yoksa bu adımı ATLA — görev takibi opsiyonel).

> **Plane CLI kullanımı `plane-cli` skill'ine devredilir.** Tüm `plane-cli` komut sözdizimi, UUID semantiği (`PROJ-N` → `issue get-id`), `--json` parse, REPLACE (`update --assignees/--labels`) vs incremental (`assignee/label --add`) farkı, enum'lar ve hata kodları için **`plane-cli` skill'inin kurallarına uy** (`~/.claude/skills/plane-cli/SKILL.md`). Bu skill yalnızca **commit'e özgü iş kurallarını** (hangi issue, completed'e çekme, self atama, label tipi, branch-bazlı tarih) tanımlar; çağrıların nasıl yapılacağı `plane-cli` skill'inin sorumluluğundadır.

Açık issue'ları listele (proje UUID ile), yapılan değişikliklerle uyuşan bir issue var mı tespit et:
- **Var**: issue UUID'sini sakla (sonra hem completed state'e çek hem de eksik alanları doldur — bkz. "Plane Alan Doldurma")
- **Yok**: bulgu olarak işaretle (yeni issue önerisi için — create sırasında tüm alanlar doldurulur)

Her iki durumda da issue oluşturma/güncelleme **"Plane Alan Doldurma Kuralları"** bölümüne göre alanları (self assignee, tarihler, label) set eder.

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

**S3 — Plane** (proje UUID tanımlıysa; yoksa bu soruyu sorma)
- Issue varsa: header "Plane", question "PROJ-X issue'sunu kapatayım mı (completed)? Eksik alanlar (self atama, tarihler, label) da tamamlanır.", options ["Evet kapat (completed)", "Açık bırak"]
- Issue yoksa: question "Bu değişiklik için Plane'de issue oluşturayım mı (completed olarak)? Self atanır, tarih + label set edilir.", options ["Evet", "Hayır"]

"Evet" seçilirse 10. adımda issue oluşturma/güncelleme **10a Alan Doldurma Kuralları**'na göre yapılır (self assignee, tarihler, label; priority'ye dokunulmaz).

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

### 10. Plane Issue Kapatma + Alan Doldurma

> **CLI sözdizimi `plane-cli` skill'inden gelir.** Aşağıdaki adımlar **ne yapılacağını** (hangi işlem, hangi alan) söyler; UUID çözme, `--json` parse, `create`/`update`/`assignee --add`/`label --add` komutlarının tam sözdizimi, REPLACE vs incremental farkı ve hata kodları için **`plane-cli` skill'inin kurallarına uy**. Burada komutları tekrar yazma — `plane-cli` skill'i kanonik kaynaktır.

Plane state UUID tabanlıdır — **kapatma = issue'yu `completed` group state'ine çekmek** (boolean değil). Gereken UUID'leri `plane-cli` ile çöz: SELF user (member me), `completed` group state (state list), `hata`/`geliştirme` label (label list). Sonra **"Plane Alan Doldurma Kuralları"** bölümüne göre alanları hazırla (self, tarihler, label).

#### Yeni Issue (Soru 3'te "Evet oluştur" seçildiyse)
0'dan oluşturulurken **tüm alanlar tek `issue create` çağrısında** verilir (self assignee + tarihler + label), sonra ayrı bir `issue update` ile `completed` group state'ine çekilir. Priority **set edilmez**.

#### Mevcut Issue (Soru 3'te "Evet kapat" seçildiyse)
Mevcut issue'da **eksik alanlar tamamlanır, dolu olanlar korunur**. Liste alanlarında (assignee/label) **incremental ekleme** kullan (REPLACE yapan `update --assignees/--labels` değil — bkz. `plane-cli` skill'i):

1. Issue'nun mevcut halini al (`issue get`), eksik alanları tespit et.
2. **Self assignee yoksa** incremental ekle (`issue assignee --add`; mevcut atananları korur).
3. **Label yoksa** incremental ekle (`issue label --add`; mevcut label'ları korur).
4. **Tarihler boşsa** doldur (`issue update` ile sadece eksik olanı; dolu olana dokunma).
5. `completed` group state'ine çek (`issue update --state`).

### 10a. Plane Alan Doldurma Kuralları

İssue oluşturulurken/güncellenirken aşağıdaki alanlar şu kurallarla doldurulur. **Öncelik (priority) set EDİLMEZ** — bu skill priority'ye dokunmaz. CLI komutlarının tam sözdizimi için `plane-cli` skill'ine bak.

#### Assignee — Self
- `plane-cli` skill'i üzerinden `member me` ile şu anki kullanıcının UUID'sini al.
- **Yeni issue**: `create` çağrısında self assignee ver.
- **Mevcut issue**: atananlar arasında self yoksa **incremental** (`issue assignee --add`) ile ekle — REPLACE yapan `update --assignees` kullanma.

#### Label — hata / geliştirme
- Tipi **agent kendisi belirler**: review/commit ettiği işin doğasına göre bir **bug fix** ise `hata`, yeni özellik/iyileştirme/refactor/chore ise `geliştirme`. Kullanıcıya ayrıca sorma — yaptığın işi zaten biliyorsun.
- `label list` ile UUID'sini çöz. **Label projede yoksa `plane-cli` ile oluştur** (`label create "hata"` veya `"geliştirme"`), sonra ata.
- **Yeni issue**: `create` çağrısında label ver.
- **Mevcut issue**: o label yoksa **incremental** (`issue label --add`) ile ekle — REPLACE yapan `update --labels` kullanma.

#### Tarihler — start-date / target-date (ISO 8601, `YYYY-MM-DD`)
Branch durumuna göre:
- **Feature branch'teyse** (`IS_MAIN=false`): `start-date` = branch'in açıldığı/ilk commit tarihi, `target-date` = bugün.
  ```bash
  START=$(git log "$DEFAULT_BRANCH".."$CURRENT_BRANCH" --format=%cs --reverse 2>/dev/null | head -1)
  [ -z "$START" ] && START=$(git log -1 --format=%cs "$(git merge-base "$DEFAULT_BRANCH" "$CURRENT_BRANCH")" 2>/dev/null)
  [ -z "$START" ] && START=$(date +%Y-%m-%d)
  TARGET=$(date +%Y-%m-%d)
  ```
- **Ana branch'teyse** (`IS_MAIN=true`): `start-date` = `target-date` = bugün (`date +%Y-%m-%d`).
- **Mevcut issue güncellemesinde**: yalnızca **boş** olan tarih alanını doldur — issue'da zaten dolu olan `start_date`/`target_date` değerine **dokunma**.

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
- `~/.claude/rules/plane.md` — Plane ID semantiği + CLI kuralları
- `plane-cli` skill — Plane CLI komut sözdizimi (adım 3e/10/10a buna devreder)
- `worktree` skill (varsa) — worktree teslim akışı
