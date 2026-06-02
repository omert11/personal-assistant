---
name: full-translation
description: Django projesinde tüm dillerin eksik/fuzzy çevirilerini uçtan uca tamamlar (makemessages → po-cli → paralel ajan çeviri → compile → commit).
when_to_use: Trigger — "tam çeviri akışı", "tüm dilleri çevir", "eksik çevirileri tamamla (tüm diller)", "translation workflow", "i18n sync", "/full-translation". Tek .po dosyası için po-cli skill yeterli; bu skill ÇOK DİL + ÇOK DOMAIN uçtan uca akış içindir (makemessages + paralel Workflow ajanları + compilemessages + commit).
allowed-tools: Bash, Read, Write, Edit, Glob, Task, Workflow, AskUserQuestion
---

# Full Translation Workflow

Django gettext projesinde **tüm dillerin** eksik (untranslated) ve fuzzy çevirilerini **tek seferde**, paralel ajanlarla uçtan uca tamamlar. Diji B2C projeleri (voyante-web/Zenrota gibi) için 3 domain (`django`, `djangojs`, `djangof7`) + N dil matrisini kapsar.

> **po-cli skill'inden farkı**: po-cli **tek bir `.po` dosyasını** analiz edip çevirir. Bu skill **tüm dil × domain matrisini** orkestre eder: makemessages ile metin çıkarma, dil başına paralel çeviri ajanı (Workflow tool), compile ve commit dahil. İçeride po-cli'nin `analyze`/`update` komutlarını kullanır — onu tekrar etmez, ona dayanır.

## Önkoşullar

- `po-cli` binary kurulu (`po-cli --version`). Yoksa po-cli skill'indeki kurulumu uygula.
- `gettext` (`xgettext`, `msgfmt`) kurulu.
- venv aktif (`~/.claude/rules/python.md`: `source .venv/bin/activate`, `uv run` kullanma).
- Diji F7 projesi ise `makemessagesf7` custom command'ı mevcut (`common/management/commands/makemessagesf7.py`).

## Akış (7 adım)

### Adım 0 — Repoları güncelle

Base branch (genelde `stage`) + **mobil repo** (varsa) pull edilir. **Mobil pull ŞARTTIR**: `makemessagesf7` `F7_ROOT` (varsayılan `"mobile"`) dizinini tarar — mobil repo güncel değilse yeni F7 metinleri `djangof7.pot`'a girmez.

```bash
git checkout <base> && git pull --ff-only origin <base>     # çakışma → DUR, kullanıcıya bildir
git -C mobile/<app> checkout main && git -C mobile/<app> pull --ff-only origin main
```

Uncommitted `.po` değişikliği varsa pull engellenir → önce `commit` skill ile commit'le, gerekirse `git rebase origin/<base>` (çakışma çıkarsa kullanıcıya sor).

### Adım 1 — makemessages (tüm diller, 3 domain)

```bash
source .venv/bin/activate
python manage.py makemessages -d django --all
python manage.py makemessages -d djangojs --all
python manage.py makemessagesf7 -d djangof7 --all        # F7 projesi ise; mobil dizini tarar
```

> Devasa diff normaldir: çoğu `#: app/file.py:123` **kaynak konum yorumu**. Gerçek iş = eklenen/çıkan `msgid` sayısı (`git diff | grep -c '^+msgid'`).

### Adım 2-3 — po-cli analyze → /tmp json çıktılar

`en` (kaynak dil) **hariç** her `locale/<lang>/LC_MESSAGES/<domain>.po` için:

```bash
mkdir -p /tmp/<proj>-i18n
po-cli --json analyze <po> > /tmp/<proj>-i18n/<lang>.<domain>.analysis.json
```

> ⚠️ `--json` **GLOBAL flag** — `po-cli --json analyze ...` doğru. Alt komuttan sonra (`po-cli analyze ... --json`) çalışmaz.

İstatistik özeti çıkar (`statistics.untranslated` + `statistics.fuzzy`). Tümü 0 ise dur ("tüm diller temiz"). zsh'de dil listesini **array** olarak ver (`LANGS=(ar de ...)`), düz string word-splitting'e güvenme.

### Adım 4 — Workflow: dil başına 1 ajan paralel çeviri

`Workflow` tool ile **dil başına 1 ajan** (`parallel`, cap ~10 eşzamanlı). Her ajan kendi dilinin analysis json'larını **Read** eder, entry'leri çevirir, `<lang>.<domain>.translations.json` yazar (po-cli `update` formatı: `[{msgid, msgstr, context}]`).

**Ajan prompt'una MUTLAKA gömülecek kurallar:**

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

Ajan StructuredOutput ile `{lang, <domain>_count, notes}` döndürür.

Workflow script iskeleti (inline):

```js
export const meta = {
  name: '<proj>-i18n-translate',
  description: 'Dil başına 1 ajan: eksik/fuzzy entryleri tek tek çevirip translations.json yazar',
  phases: [{ title: 'Translate' }],
}
const OUT = '/tmp/<proj>-i18n'
const LANGS = [
  { code: 'ar', name: 'Arapça',  pluralNote: 'nplurals=6: zero/one/two/few/many/other.' },
  { code: 'ja', name: 'Japonca', pluralNote: 'nplurals=1: TEK form; plural string varsa msgstr[1] OLMAMALI.' },
  { code: 'ru', name: 'Rusça',   pluralNote: 'nplurals=4: one/few/many/other.' },
  // ... diğer diller (tr/de/es/hi/kk/tk/tg=2, uz/zh_Hans=1)
]
const DOMAINS = ['django', 'djangof7']   // iş olan domainler (djangojs genelde 0)
phase('Translate')
const results = await parallel(LANGS.map((L) => () =>
  agent(
`Profesyonel lokalizasyon uzmanısın. Hedef dil: ${L.name} (${L.code}).
Şu json'ları OKU: ${DOMAINS.map(d => `${OUT}/${L.code}.${d}.analysis.json`).join(', ')}
untranslated_entries + fuzzy_entries'i ÇEVİR.
KURALLAR: (1) her entry TEK TEK, toplu replace YASAK. (2) fuzzy msgstr'ye GÜVENME, msgid'den sıfırdan.
(3) placeholder/%%/HTML/URL/JS birebir koru. (4) URL slug'ı mevcut konvansiyona uydur.
(5) marka adları İngilizce. (6) ${L.pluralNote} (7) msgstr boş bırakma.
Her domain için ${OUT}/${L.code}.<domain>.translations.json YAZ (dizi: {msgid,msgstr,context}).`,
    { label: `translate:${L.code}`, phase: 'Translate',
      schema: { type:'object', required:['lang'], properties:{ lang:{type:'string'}, notes:{type:'string'} } } }
  ).then((r) => ({ ...r, code: L.code }))
))
return results
```

### Adım 5 — Apply (TEK toplu onay) + perl temizlik

Tüm ajanlar bitince **önce dry-run validate**, sonra **TEK `AskUserQuestion` onayı**, sonra apply. Her dosya için:

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
