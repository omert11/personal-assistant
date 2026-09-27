---
name: full-translation
description: Django projesinde tüm dillerin eksik/fuzzy çevirilerini makemessages'tan commit'e tamamlar.
when_to_use: Trigger — "tam çeviri akışı", "tüm dilleri çevir", "eksik çevirileri tamamla (tüm diller)", "translation workflow", "i18n sync", "/full-translation". Tek .po dosyası için po-cli skill yeterli; bu skill ÇOK DİL + ÇOK DOMAIN uçtan uca akış içindir (makemessages + paralel çeviri sub-agent'ları + compilemessages + commit).
allowed-tools: Bash, Read, Write, Edit, Glob, Task, AskUserQuestion
---

# Full Translation

Domain'ler: `django`, `djangojs`, `djangof7` (F7 projesi ise) × tüm diller. Tek `.po` analiz/update için `po-cli` skill'ine dayanır.

## Önkoşullar

- `po-cli` kurulu (`po-cli --version`); yoksa po-cli skill'indeki kurulumu uygula.
- `gettext` (`xgettext`, `msgfmt`) kurulu.
- venv: `.venv` yoksa `uv venv && uv pip install -r requirements.txt`; sonra `source .venv/bin/activate` ve düz `python ...`. `uv run` kullanma.
- F7 projesi ise `makemessagesf7` command'ı mevcut (`common/management/commands/makemessagesf7.py`).

## Akış

### Adım 0 — Repoları güncelle (ATLANAMAZ, ilk iş)

`makemessagesf7` mobil dizini (`F7_ROOT`, varsayılan `"mobile"`) o anki haliyle tarar; mobil repo gerideyse yeni F7 metinleri `djangof7.pot`'a girmez ve "0 untranslated/0 fuzzy" sahte-temiz görünür. 0 = "metin çıkarılmadı" olabilir.

```bash
# 1) Base branch
git checkout <base> && git pull --ff-only origin <base>     # çakışma → DUR, kullanıcıya bildir
# 2) MOBİL — mobile/<app>/.git varsa koşulsuz ZORUNLU
git -C mobile/<app> checkout main && git -C mobile/<app> pull --ff-only origin main
# Doğrulama
git -C mobile/<app> log --oneline -1            # HEAD ilerledi mi
git -C mobile/<app> status -sb                  # "behind" KALMAMALI
```

- Mobil HEAD `origin/main`'e eşit değilse DUR, Adım 1'e geçme.
- `mobile/<app>` dizini yoksa mobil pull'u atla; varsa hiçbir gerekçeyle ("zaten güncel", "az önce baktım", "küçük değişiklik") atlama.
- Uncommitted `.po` pull'u engellerse → `commit` skill ile commit'le, gerekirse `git rebase origin/<base>` (çakışma → kullanıcıya sor).
- Self-check: "Mobil repo var mı? Varsa pull ettim ve HEAD=origin/main mı?" Değilse Adım 0 bitmedi.

### Adım 1 — makemessages

```bash
source .venv/bin/activate
python manage.py makemessages -d django --all
python manage.py makemessages -d djangojs --all
python manage.py makemessagesf7 -d djangof7 --all        # F7 projesi ise
```

Diff'in çoğu `#: app/file.py:123` konum yorumudur; gerçek iş = `git diff | grep -c '^+msgid'`.

### Adım 2-3 — po-cli analyze

Kapalı (hidden) diller analiz, çeviri ve yakınsama dışında tutulur (`.po`'ları silinmez; makemessages dokunabilir). Tespit (yoksa boş döner):

```bash
python -c "
import importlib
try:
    opts = importlib.import_module('djangomain.app_options')
    print(' '.join(sorted(getattr(opts, 'HIDDEN_LANGUAGES', set()))))
except ModuleNotFoundError:
    pass"
```

`LANGS = tüm locale dilleri − en − HIDDEN_LANGUAGES`. zsh'de array ver (`LANGS=(ar de ...)`), string word-splitting'e güvenme. Her `locale/<lang>/LC_MESSAGES/<domain>.po` için:

```bash
mkdir -p /tmp/<proj>-i18n
po-cli --json analyze <po> > /tmp/<proj>-i18n/<lang>.<domain>.analysis.json
```

`--json` global flag'tir: alt komuttan önce yaz (`po-cli analyze ... --json` çalışmaz).

### Adım 4 — Çeviri (iş birimi = entry sayısı, dil değil)

**4a** — Tüm dil × domain için `statistics.untranslated + statistics.fuzzy` topla → `TOTAL`.

**4b** — Eşik:
- `TOTAL == 0` → Adım 4–5'i atla, Adım 6 + 7 yine çalışır.
- `TOTAL ≤ 200` → sub-agent spawn etme. Analiz json'larını oku, kendin çevir, her `<lang>.<domain>.translations.json`'ı kendin yaz.
- `TOTAL > 200` → chunk başına 1 sub-agent (hepsi paralel).

**4c** — Chunk'lama (`TOTAL > 200`): dilleri count'a göre sırala, ~200'ü aşana kadar chunk'a dil dil ekle. Bir dili iki ajana bölme; tek istisna dilin kendisi >200 ise (o dil kendi chunk'ı olur, ajan 200'erli işler; prompt'a o dilin mevcut slug örneklerini göm). Algoritma: aşağıdaki `packChunks`.

Her çeviri sub-agent'ı chunk'ındaki dillerin analiz json'larını okur, her dil × domain için `<lang>.<domain>.translations.json` yazar (po-cli `update` formatı: `[{msgid, msgstr, context}]`), aşağıdaki çıktı şemasıyla `{langs:[...], notes}` döner.

**Çeviri kuralları (inline'da uygula, ajan prompt'una göm):**

1. Her entry tek tek, bağlamıyla çevrilir. `sed`/`replace_all`/toplu string-replace YASAK.
2. Fuzzy msgstr'ye güvenme (yanlış otomatik eşleşme, örn. "Yacht"→"araç"); yok say, `msgid`'den sıfırdan çevir.
3. Placeholder birebir: `%(name)s`, `%s`, `%d`, `%%` (literal yüzde), `{var}`, `{0}`, `{{ var }}`, `{% tag %}`. HTML tag, URL, JS kod parçası birebir.
4. URL slug'ları (i18n_patterns route'ları, örn. `yachts/`, `ports/<int:page>/`) lokalize edilir; hedef dilin mevcut slug konvansiyonuna uy — referans: aynı dosyada `airports/`/`cities/` (tr: `tum-havalimanlari/`, de: `flughaefen/`, ar: `المطارات/`). Mevcut slug'ları Latin olan diller (genelde hi/ja/kk/ru/tk/uz/zh_Hans) yenisini de Latin bırakır.
5. Marka/fare adları çevrilmez: "Economy Flex", "SunFlex 7", "Business", "Transporter", "Vito".
6. nplurals (po-cli validate yakalamaz, `compilemessages`'ta patlar):
   - `ja, zh_Hans, uz` = 1 (sadece `msgstr[0]`; `msgstr[1]` OLMAMALI)
   - `ru` = 4 (one/few/many/other), `ar` = 6 (zero/one/two/few/many/other)
   - `tr, de, es, hi, kk, tk, tg` = 2
7. msgstr boş bırakılmaz.

Sub-agent planı (sadece `TOTAL > 200`):

1. Girdiler (ana agent doldurur):
   - `OUT = /tmp/<proj>-i18n`
   - `DOMAINS` — iş olan domainler (örn. `django`, `djangof7`; `djangojs` genelde 0).
   - `LANGS` — `{code, name, pluralNote, count}` listesi; `count` = o dilin tüm domainlerdeki untranslated+fuzzy toplamı. HIDDEN_LANGUAGES'taki dilleri EKLEME. Örnek pluralNote: `ar` → "nplurals=6: zero/one/two/few/many/other.", `ja` → "nplurals=1: TEK form; plural string varsa msgstr[1] OLMAMALI.", `ru` → "nplurals=4: one/few/many/other." (tr/de/es/hi/kk/tk/tg=2, uz/zh_Hans=1).
2. Ana agent chunk'ları hesaplar: `CHUNKS = packChunks(LANGS.filter(L => L.count > 0))`

   ```js
   // dil sınırında ~200'lük chunk'lar (bir dili bölme; tek dil >200 ise kendi chunk'ı)
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
   ```
3. Tek faz (Translate): her chunk için 1 sub-agent, hepsi aynı anda paralel spawn edilir. Etiket: `translate:chunk<i>(<kodlar>)`. Model/effort `core` kuralındaki tablodan.
4. Brief şablonu (`<langBlock>` = chunk'taki her dil için bir satır: `- <name> (<code>) — OKU: <OUT>/<code>.<domain>.analysis.json, ... (her DOMAIN) | plural: <pluralNote>`):

   ```text
   Profesyonel lokalizasyon uzmanısın. Bu chunk'taki HER dil için çeviri yap:
   <langBlock>
   Her dilin untranslated_entries + fuzzy_entries'ini ÇEVİR.
   KURALLAR: (1) her entry TEK TEK, toplu replace YASAK. (2) fuzzy msgstr'ye GÜVENME, msgid'den sıfırdan.
   (3) placeholder/%%/HTML/URL/JS birebir koru. (4) URL slug'ı o dilin mevcut konvansiyonuna uydur.
   (5) marka adları İngilizce. (6) plural'da yukarıdaki dil-bazlı nplurals notunu uygula. (7) msgstr boş bırakma.
   Her dil×domain için <OUT>/<lang>.<domain>.translations.json YAZ (dizi: {msgid,msgstr,context}).
   ```
5. Zorunlu çıktı şeması:

   ```json
   { "type": "object", "required": ["langs"], "properties": { "langs": { "type": "array", "items": { "type": "string" } }, "notes": { "type": "string" } } }
   ```
6. Sonuçları topla; her sonucu chunk'ın dil kodlarıyla eşleştir. Hata/boş dönen ya da `langs`'ı chunk'la uyuşmayan sub-agent'ı aynı brief'le yeniden spawn et.

### Adım 5 — Apply

Tüm `translations.json`'lar hazır olunca: önce her dosyada dry-run validate, sonra soru aracıyla TEK onay, sonra apply:

```bash
po-cli --json update <po> -t <translations.json> --dry-run    # validation.valid kontrol
po-cli --json update <po> -t <translations.json>              # apply
perl -0777 -i -pe 's/\n#, fuzzy\nmsgid ""\nmsgstr ""\n+/\n/g' <po>   # her apply'dan sonra ZORUNLU
```

- perl: `po-cli update` dosya sonuna `#, fuzzy` + boş `msgid ""`/`msgstr ""` bırakır → `compilemessages` "duplicate message definition" FATAL. Obsolete `#~` bloklarına dokunmaz.
- `validation.invalids` doluysa (Missing variables / HTML tags / URL changed) entry'yi düzelt, translations.json'ı güncelle, dry-run tekrar. `--no-strict`/`--force` kullanma.

### Adım 6 — compile + re-analyze

Çeviri olmasa bile (`TOTAL == 0`) compile + commit ZORUNLU: makemessages `.po`'yu yeniden formatlar (line-wrap, `POT-Creation-Date`/header, konum yorumları, `#~` sırası); runtime `.mo`'yu okur, `.mo` tracked'dir → `.po` + `.mo` senkron gönderilmeli. Tek istisna: `git status --porcelain -- 'locale/**/*.po'` boşsa akış temiz biter.

```bash
msgfmt --check <po> -o /dev/null 2>&1 | grep -v "warning:"     # boşsa OK (dosya bazlı fatal taraması)
python manage.py compilemessages                               # .po → .mo
# Re-analyze: LANGS × domain po-cli --json analyze
```

- `compilemessages` plural/duplicate FATAL → dosyayı düzelt (nplurals tablosu / perl) → tekrar.
- Re-analyze'da untranslated/fuzzy kaldıysa → Adım 3'e dön (kalan entry'ler için).
- "Tüm diller temiz" HIDDEN_LANGUAGES hariç değerlendirilir.
- Duplicate'i `grep '^msgid ""$'` ile sayma (uzun msgid wrapping'i de eşleşir); test `msgfmt --check`.
- `update_translation_fields` bu akışta çağrılmaz.

### Adım 7 — commit

`.po` diff'i varsa (çeviri veya sadece yeniden format) `commit` skill'i tetikle; `.po` + `.mo` birlikte commit'lenir. `.po` git status'ta boşsa commit atla.

## Komut Referansı (po-cli)

```bash
po-cli --json analyze <po>                       # eksik/fuzzy + istatistik (JSON)
po-cli --json update <po> -t <json> --dry-run    # validate (yazmaz)
po-cli --json update <po> -t <json>              # apply
# Çıktı: {validation:{valid,invalids[],total}, update:{success,updated_entries,errors[]}}
```

## İlişkili

- `po-cli` skill — tek `.po` analiz/çeviri/validate
- `commit` skill — Adım 7
- `django` skill — F7 çeviri domain'i, `makemessagesf7`
- `obsidian-search` — vault'ta çeviri tuzakları (`i18n`, `po-cli`, `çeviri`)
