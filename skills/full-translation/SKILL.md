---
name: full-translation
description: Django projesinde tüm dillerin eksik/fuzzy çevirilerini uçtan uca tamamlar (makemessages → po-cli → entry yüküne göre çeviri → compile → commit).
when_to_use: Trigger — "tam çeviri akışı", "tüm dilleri çevir", "eksik çevirileri tamamla (tüm diller)", "translation workflow", "i18n sync", "/full-translation". Tek .po dosyası için po-cli skill yeterli; bu skill ÇOK DİL + ÇOK DOMAIN uçtan uca akış içindir (makemessages + paralel Workflow ajanları + compilemessages + commit).
allowed-tools: Bash, Read, Write, Edit, Glob, Task, Workflow, AskUserQuestion
---

# Full Translation Workflow

Django gettext projesinde **tüm dillerin** eksik (untranslated) ve fuzzy çevirilerini **tek seferde**, paralel ajanlarla uçtan uca tamamlar. Diji B2C projeleri (voyante-web/Zenrota gibi) için 3 domain (`django`, `djangojs`, `djangof7`) + N dil matrisini kapsar.

> **po-cli skill'inden farkı**: po-cli **tek bir `.po` dosyasını** analiz edip çevirir. Bu skill **tüm dil × domain matrisini** orkestre eder: makemessages ile metin çıkarma, **iş yüküne göre** çeviri (≤200 entry inline, fazlası ~200'lük chunk'lara bölünüp paralel Workflow ajanlarıyla), compile ve commit dahil. İçeride po-cli'nin `analyze`/`update` komutlarını kullanır — onu tekrar etmez, ona dayanır.

## Önkoşullar

- `po-cli` binary kurulu (`po-cli --version`). Yoksa po-cli skill'indeki kurulumu uygula.
- `gettext` (`xgettext`, `msgfmt`) kurulu.
- venv aktif (`~/.claude/rules/python.md`: `source .venv/bin/activate`, `uv run` kullanma).
- Diji F7 projesi ise `makemessagesf7` custom command'ı mevcut (`common/management/commands/makemessagesf7.py`).

## Akış (7 adım)

### Adım 0 — Repoları güncelle  ⛔ ATLANAMAZ, AKIŞIN İLK İŞİ

> **MOBİL PULL = ÇEVİRİNİN BİR NUMARALI ÖN KOŞULU. Atlanırsa çeviri SESSİZCE EKSİK kalır ve bunu fark etmezsin.**
>
> `makemessagesf7` mobil dizinini (`F7_ROOT`, varsayılan `"mobile"`) **çalıştığı anki haliyle** tarar. Mobil repo geride ise yeni F7 metinleri `djangof7.pot`'a **hiç girmez** → o dilde "0 untranslated/0 fuzzy" çıkar → bunu yanlışlıkla **"F7 temiz"** sanırsın. **0, "çevrildi" değil "metin hiç çıkarılmadı" demek olabilir.** Bu sahte-temiz, eksik bir release'e (yanlış tag'e) yol açar.
>
> **Somut kanıt (2026-06-09, v5.6.12):** mobil pull atlandı → `djangof7` her dilde `0u/0f` göründü, "temiz" sanıldı, v5.6.12 tag'i atıldı. Tag SONRASI mobil pull edilince makemessagesf7 **208 yeni msgid + her dilde 1 fuzzy** çıkardı — yani release eksik çıkmıştı, tag re-point gerekti. (Detay: [[full-translation-workflow]])

**KESİN SIRA — başka hiçbir şeyden ÖNCE:**

```bash
# 1) Base branch
git checkout <base> && git pull --ff-only origin <base>     # çakışma → DUR, kullanıcıya bildir
# 2) MOBİL — ZORUNLU, koşulsuz. Proje mobil repo içeriyorsa (mobile/<app>/.git varsa) ASLA atlama.
git -C mobile/<app> checkout main && git -C mobile/<app> pull --ff-only origin main
```

**Doğrulama (pull'un gerçekten yeni commit getirip getirmediğini GÖR, körlemesine geçme):**

```bash
git -C mobile/<app> log --oneline -1            # HEAD ilerledi mi
git -C mobile/<app> status -sb                  # "behind" KALMAMALI
```

`makemessagesf7`'yi çalıştırmadan önce mobil HEAD'in `origin/main` ile **eşit** olduğunu teyit et. Eşit değilse **DUR** — Adım 1'e geçme.

- Mobil repo **yoksa** (`mobile/<app>` dizini hiç yoksa) bu adımı atla; ama dizin **varsa** pull **koşulsuz zorunludur** ("zaten günceldir", "az önce baktım", "küçük değişiklik" gerekçeleri geçersiz).
- Uncommitted `.po` değişikliği varsa pull engellenir → önce `commit` skill ile commit'le, gerekirse `git rebase origin/<base>` (çakışma çıkarsa kullanıcıya sor).
- **Self-check (Adım 1'e geçmeden):** "Mobil repo var mı? Varsa pull ettim ve HEAD=origin/main mı?" İkisi de evet değilse Adım 0 bitmemiştir.

### Adım 1 — makemessages (tüm diller, 3 domain)

```bash
source .venv/bin/activate
python manage.py makemessages -d django --all
python manage.py makemessages -d djangojs --all
python manage.py makemessagesf7 -d djangof7 --all        # F7 projesi ise; mobil dizini tarar
```

> Devasa diff normaldir: çoğu `#: app/file.py:123` **kaynak konum yorumu**. Gerçek iş = eklenen/çıkan `msgid` sayısı (`git diff | grep -c '^+msgid'`).

### Adım 2-3 — po-cli analyze → /tmp json çıktılar

> **⛔ Kapalı (hidden) diller ÇEVRİLMEZ.** Proje dil gizleme kullanıyorsa
> (`djangomain/app_options.py` içinde `HIDDEN_LANGUAGES`, örn. voyante-web'de
> Ticket#61613 ile es/uz/kk/tk/tg/zh-hans/ja/hi kapatıldı), bu diller analiz ve
> çeviri matrisinden **tamamen çıkarılır** — kullanıcıya kapalı dile çeviri
> eforu/token harcanmaz. `.po` dosyaları silinmez, makemessages'ın onlara
> dokunması sorun değil; sadece analyze + translate + yakınsama dışında tutulur.
>
> ```bash
> # Kapalı dilleri dinamik tespit et (yoksa boş döner):
> python -c "
> import importlib
> try:
>     opts = importlib.import_module('djangomain.app_options')
>     print(' '.join(sorted(getattr(opts, 'HIDDEN_LANGUAGES', set()))))
> except ModuleNotFoundError:
>     pass"
> ```
>
> Dil array'ini kurarken: `LANGS = tüm locale dilleri − en − HIDDEN_LANGUAGES`.

`en` (kaynak dil) ve **HIDDEN_LANGUAGES** hariç her `locale/<lang>/LC_MESSAGES/<domain>.po` için:

```bash
mkdir -p /tmp/<proj>-i18n
po-cli --json analyze <po> > /tmp/<proj>-i18n/<lang>.<domain>.analysis.json
```

> ⚠️ `--json` **GLOBAL flag** — `po-cli --json analyze ...` doğru. Alt komuttan sonra (`po-cli analyze ... --json`) çalışmaz.

İstatistik özeti çıkar (`statistics.untranslated` + `statistics.fuzzy`). Tümü 0 ise dur ("tüm diller temiz"). zsh'de dil listesini **array** olarak ver (`LANGS=(ar de ...)`), düz string word-splitting'e güvenme.

### Adım 4 — Çeviri: iş **entry sayısına** göre paylaştırılır (dil başına DEĞİL)

> **İş birimi = çevrilecek entry sayısı, dil değil.** Bir dilde 2 entry, diğerinde 0 olabilir — "dil başına 1 ajan" hem dengesizdir hem de toplam iş azken Workflow'u boş yere kurar. Önce toplam yükü hesapla, sonra böl.

**4a — Toplam çevrilecek entry'yi hesapla.** Adım 2-3'teki analiz json'larından (HIDDEN_LANGUAGES + `en` hariç) tüm dil × domain için `statistics.untranslated + statistics.fuzzy` topla → `TOTAL`.

**4b — Eşik kararı:**

- **`TOTAL == 0`** → dur ("tüm diller temiz").
- **`TOTAL ≤ 200`** → **Workflow KURMA.** Tek ajanlık iştir; orchestrator (sen) ilgili analiz json'larını **Read** edip entry'leri aşağıdaki kurallarla **kendin** çevirir ve her `<lang>.<domain>.translations.json` dosyasını **kendin** yazarsın. Paralel ajan/Workflow gereksiz overhead'dir.
- **`TOTAL > 200`** → `Workflow` tool ile **chunk başına 1 ajan**. Chunk'lama **dil sınırında kesilir** (aşağıdaki 4c).

**4c — Chunk'lama (sadece `TOTAL > 200`): dil sınırında bin-packing.**

Dilleri entry sayısıyla sırala; bir chunk'a dil dil ekle, ~200'ü aşacaksan yeni chunk aç. **Bir dili iki ajana bölme** — böylece o dilin slug konvansiyonu/terim birliği tek ajanda kalır. Tek istisna: **bir dilin kendisi >200 ise** o dil zorunlu olarak entry sırasına göre 200'lük parçalara bölünür (bu durumda prompt'a o dilin mevcut slug örneklerini de göm).

```js
// her L = { code, name, pluralNote, count }  (count = o dilin tüm domainlerdeki untranslated+fuzzy)
function packChunks(langs, target = 200) {
  const chunks = []
  let cur = [], curSum = 0
  for (const L of langs.sort((a, b) => b.count - a.count)) {
    if (L.count > target) {            // tek dil hedefi aşıyor → kendi başına chunk(lar)
      if (cur.length) { chunks.push(cur); cur = []; curSum = 0 }
      chunks.push([L])                 // ajan kendi içinde 200'erli işler; prompt'a slug örneği göm
      continue
    }
    if (curSum + L.count > target && cur.length) { chunks.push(cur); cur = []; curSum = 0 }
    cur.push(L); curSum += L.count
  }
  if (cur.length) chunks.push(cur)
  return chunks                        // her chunk = 1 ajan; chunk içinde 1+ tam dil
}
```

> **Model**: Çeviri ajanları `model: 'sonnet'` ile çalışır (opts'ta sabit). Belirtilmezse Workflow ajanı ana oturum modelini devralır — pahalı session modelinde paralel çeviri gereksiz maliyet. Sonnet çok dilli lokalizasyon için yeterli kalitede.

Her ajan **chunk'ındaki dillerin** analiz json'larını **Read** eder, entry'leri çevirir, her dil için `<lang>.<domain>.translations.json` yazar (po-cli `update` formatı: `[{msgid, msgstr, context}]`).

**Çeviri kuralları (hem inline ≤200 hem de ajan prompt'una MUTLAKA gömülür):**

1. **Her entry TEK TEK, bağlamını anlayarak çevrilir.** `sed`/`replace_all`/toplu string-replace **YASAK** — her `msgid` ayrı, anlamına göre.
2. **FUZZY msgstr'ye GÜVENME** — makemessages'ın yanlış otomatik eşleşmesidir (örn. yeni özellik eklenince "Yacht"→"araç", "Brand Localization"→"Hata Mesajı Yerelleştirme"). msgstr'yi YOK SAY, `msgid`'den sıfırdan çevir.
3. **Placeholder birebir korunur**: `%(name)s`, `%s`, `%d`, `%%` (literal yüzde — değiştirme), `{var}`, `{0}`, `{{ var }}`, `{% tag %}`. HTML tag, URL, JS kod parçası birebir.
4. **URL slug'ları lokalize edilir** (i18n_patterns route'ları, örn. `yachts/`, `ports/<int:page>/`). Hedef dilin **mevcut slug konvansiyonuna** uydur — referans: aynı dosyada `airports/`/`cities/` slug'ı nasıl çevrilmiş (tr: `tum-havalimanlari/`, de: `flughaefen/`, ar: `المطارات/`). Mevcut slug'ları Latin bırakan diller (genelde hi/ja/kk/ru/tk/uz/zh_Hans) yeni slug'ı da Latin bırakır — tutarlılık esas.
5. **Marka/fare adları çevrilmez**: "Economy Flex", "SunFlex 7", "Business", "Transporter", "Vito" İngilizce kalır.
6. **Plural form (nplurals)** — po-cli validate YAKALAMAZ, `compilemessages`'ta patlar:
   - `ja, zh_Hans, uz` = **1** (sadece `msgstr[0]`; plural string'de `msgstr[1]` OLMAMALI)
   - `ru` = **4** (one/few/many/other), `ar` = **6** (zero/one/two/few/many/other)
   - `tr, de, es, hi, kk, tk, tg` = **2** (tekil/çoğul)
7. msgstr asla boş bırakılmaz.

Ajan StructuredOutput ile `{langs:[...], notes}` döndürür (chunk birden çok dil içerebilir).

Workflow script iskeleti (sadece `TOTAL > 200` ise — `≤200` inline çevrilir, Workflow kurulmaz):

```js
export const meta = {
  name: '<proj>-i18n-translate',
  description: 'Chunk başına 1 ajan (dil sınırında bin-packed): eksik/fuzzy entryleri tek tek çevirip translations.json yazar',
  phases: [{ title: 'Translate' }],
}
const OUT = '/tmp/<proj>-i18n'
const DOMAINS = ['django', 'djangof7']   // iş olan domainler (djangojs genelde 0)
// LANGS'a HIDDEN_LANGUAGES'taki dilleri EKLEME (Adım 2-3'teki tespit komutu).
// count = o dilin tüm domainlerdeki untranslated+fuzzy toplamı (Adım 2-3 analizinden).
const LANGS = [
  { code: 'ar', name: 'Arapça',  pluralNote: 'nplurals=6: zero/one/two/few/many/other.', count: 0 },
  { code: 'ja', name: 'Japonca', pluralNote: 'nplurals=1: TEK form; plural string varsa msgstr[1] OLMAMALI.', count: 0 },
  { code: 'ru', name: 'Rusça',   pluralNote: 'nplurals=4: one/few/many/other.', count: 0 },
  // ... diğer diller (tr/de/es/hi/kk/tk/tg=2, uz/zh_Hans=1) — her birine count ekle
]
// 4c: dil sınırında ~200'lük chunk'lar (bir dili bölme; tek dil >200 ise zorunlu böl)
function packChunks(langs, target = 200) {
  const chunks = []; let cur = [], curSum = 0
  for (const L of [...langs].sort((a, b) => b.count - a.count)) {
    if (L.count > target) { if (cur.length) { chunks.push(cur); cur = []; curSum = 0 } chunks.push([L]); continue }
    if (curSum + L.count > target && cur.length) { chunks.push(cur); cur = []; curSum = 0 }
    cur.push(L); curSum += L.count
  }
  if (cur.length) chunks.push(cur)
  return chunks
}
const CHUNKS = packChunks(LANGS.filter(L => L.count > 0))
phase('Translate')
const results = await parallel(CHUNKS.map((chunk, i) => () => {
  const langBlock = chunk.map(L =>
    `- ${L.name} (${L.code}) — OKU: ${DOMAINS.map(d => `${OUT}/${L.code}.${d}.analysis.json`).join(', ')} | plural: ${L.pluralNote}`
  ).join('\n')
  return agent(
`Profesyonel lokalizasyon uzmanısın. Bu chunk'taki HER dil için çeviri yap:
${langBlock}
Her dilin untranslated_entries + fuzzy_entries'ini ÇEVİR.
KURALLAR: (1) her entry TEK TEK, toplu replace YASAK. (2) fuzzy msgstr'ye GÜVENME, msgid'den sıfırdan.
(3) placeholder/%%/HTML/URL/JS birebir koru. (4) URL slug'ı o dilin mevcut konvansiyonuna uydur.
(5) marka adları İngilizce. (6) plural'da yukarıdaki dil-bazlı nplurals notunu uygula. (7) msgstr boş bırakma.
Her dil×domain için ${OUT}/<lang>.<domain>.translations.json YAZ (dizi: {msgid,msgstr,context}).`,
    { label: `translate:chunk${i}(${chunk.map(c => c.code).join(',')})`, phase: 'Translate', model: 'sonnet',
      schema: { type:'object', required:['langs'], properties:{ langs:{type:'array',items:{type:'string'}}, notes:{type:'string'} } } }
  ).then((r) => ({ ...r, codes: chunk.map(c => c.code) }))
}))
return results
```

### Adım 5 — Apply (TEK toplu onay) + perl temizlik

Tüm `translations.json`'lar hazır olunca (inline çeviri bittiyse veya tüm ajanlar döndüyse) **önce dry-run validate**, sonra **TEK `AskUserQuestion` onayı**, sonra apply. Her dosya için:

```bash
po-cli --json update <po> -t <translations.json> --dry-run    # validation.valid kontrol
po-cli --json update <po> -t <translations.json>              # apply
perl -0777 -i -pe 's/\n#, fuzzy\nmsgid ""\nmsgstr ""\n+/\n/g' <po>   # ZORUNLU temizlik
```

> ⚠️ **perl temizliği her apply'da ZORUNLU**: `po-cli update` her çağrıda dosya sonuna `#, fuzzy` + boş `msgid ""`/`msgstr ""` bloğu bırakır → 2. `msgid ""` = `compilemessages` "duplicate message definition" FATAL. Obsolete `#~` bloklarına dokunmaz.

`validation.invalids` doluysa o entry'leri düzelt (Missing variables / HTML tags / URL changed), translations.json güncelle, dry-run tekrar. **`--no-strict`/`--force` kullanma.**

### Adım 6 — compile + re-analyze (yakınsama döngüsü)

```bash
# Önce hızlı fatal taraması (dosya bazlı hata gösterir):
msgfmt --check <po> -o /dev/null 2>&1 | grep -v "warning:"     # boşsa OK
python manage.py compilemessages                               # .po → .mo
# Re-analyze: en hariç tüm dil × domain po-cli --json analyze
```

- `compilemessages` plural/duplicate FATAL verirse → ilgili dosyayı düzelt (plural tablosu / perl) → tekrar.
- Re-analyze'da hâlâ untranslated/fuzzy varsa → **Adım 3'e dön** (kalan entry'ler için). Kaynak kod sabitse genelde **tek tur** yakınsar.
- "Tüm diller temiz" kriteri **HIDDEN_LANGUAGES hariç** değerlendirilir — kapalı dilde untranslated kalması normaldir ve akışı bloklamaz.

> ⚠️ `grep '^msgid ""$'` ile duplicate sayma — **yanıltıcı**: gettext uzun msgid'leri `msgid ""` + alt satırda devam ettirir (string wrapping), bu duplicate header değil. Gerçek test: `msgfmt --check`.

> NOT: `update_translation_fields` Diji projelerinde SDK import bug'ı (`b2b_python_sdk...yacht_rental`) ile patlayabilir — **compile/po-cli'yi ETKİLEMEZ**, bu akışta çağrılmaz.

### Adım 7 — commit skill

Tüm diller temiz (`untranslated=0`, çevrilebilir `fuzzy=0`) olunca `commit` skill tetikle. `.mo` dosyaları Diji projelerinde **tracked** (gitignore'da değil) → `.po` + `.mo` birlikte commit'lenir. `.po`/`.mo` non-kod olduğu için commit skill code-review'i atlar.

## Komut Referansı (po-cli)

```bash
po-cli --json analyze <po>                       # eksik/fuzzy + istatistik (JSON)
po-cli --json update <po> -t <json> --dry-run    # validate (yazmaz)
po-cli --json update <po> -t <json>              # apply
# Çıktı: {validation:{valid,invalids[],total}, update:{success,updated_entries,errors[]}}
```

## İlişkili Kaynaklar

- `po-cli` skill — tek `.po` dosyası analiz/çeviri/validate (bu skill onu kullanır)
- `commit` skill — Adım 7 teslimat
- `~/.claude/rules/django.md` — F7 çeviri sistemi, makemessagesf7, elastic reindex
- `~/.claude/rules/python.md` — venv/uv kuralları
- Obsidian: `voyante-web/Learnings/full-translation-workflow.md` + `po-cli-bulk-translation-pitfalls.md` (tuzaklar)
