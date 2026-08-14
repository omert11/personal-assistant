---
name: deslop
description: AI yazim izlerini son kullanici yuzeylerinde paralel agent'larla temizler.
when_to_use: Trigger — "slop temizle", "AI izlerini temizle", "deslop", "metni insanlastir", "yapay zeka kokusunu al", `/deslop [dosya|glob|dizin]...`. Argumansiz cagrilirsa git degisikliklerini tarar. Yalniz son kullanicinin gordugu yuzeyleri duzenler; kod mantigina, yorumlara ve agent talimatlarina dokunmaz.
disable-model-invocation: false
allowed-tools: Bash(git *), Bash(claude *), Bash(cd *), Bash(find *), Bash(ls *), Read, AskUserQuestion, TaskCreate, TaskUpdate
---

# deslop — yönetici

Girdi: `$ARGUMENTS` — dosya yolu, glob veya dizin listesi. Boş bırakılabilir.

## Yasak

- Dosya açmak, okumak, içeriğine bakmak.
- Kapsam kararı vermek ("bu user-facing mi", "burada UI string var mı") — `do-deslop`'a aittir.
- Metin düzeltmek, kural okumak, `~/.cache/deslop-sources/` veya `ai-writing-rules.md` okumak.

İzin: alt oturum rapor dosyasını `Read`, `git diff`, `git status`, `find`.

## 1. Kök

`git rev-parse --show-toplevel` → `<repo>`. Git deposu değilse ve argüman yoksa `AskUserQuestion`.

## 2. Yol listesi

Argümanlı:

```bash
find $ARGUMENTS \
  \( -path '*/.git/*' -o -path '*/node_modules/*' -o -path '*/vendor/*' \
     -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.next/*' \
     -o -path '*/.venv/*' -o -path '*/target/*' \
     -o -name '*.min.*' -o -name '*.lock' -o -name '*.map' \) -prune -o \
  -type f -size -1024k -print0 2>/dev/null | xargs -0 grep -Il '' 2>/dev/null
```

Argümansız:

```bash
{ git diff --name-only --diff-filter=d HEAD; git ls-files --others --exclude-standard; } \
  | sort -u \
  | grep -vE '(^|/)(\.git|node_modules|vendor|dist|build|\.next|\.venv|target)/' \
  | tr '\n' '\0' | xargs -0 -I{} find {} -type f -size -1024k -print 2>/dev/null \
  | tr '\n' '\0' | xargs -0 grep -Il '' 2>/dev/null
```

`git status --porcelain | cut -c4-` **kullanılmaz**: rename satırı (`R old -> new`) tek yol sanılır
ve silinen yollar listeye girer. `--diff-filter=d` silinenleri düşürür, `--name-only` rename'in
yeni adını verir.

`-size -1024k`, `-1M` değil — BSD `find` `M`'i yukarı yuvarlar, liste sessizce boşalır.

Eleme yalnız mekaniktir. `CLAUDE.md`, `rules/`, `skills/`, test, config, `.py` listede kalır.

Değişiklik yoksa `AskUserQuestion`: repo geneli mi, dosya mı.

## 3. Hacim kapısı

Liste > 40 ise `AskUserQuestion` — header `Hacim`, options `["Devam et", "Daralt", "İptal"]`.

## 4. Dağıt

Gruplama ölçütü **dizin**. Grup başına dosya limiti yok.

```bash
cd <repo> && claude --model opus --effort low -p '/personal-assistant:do-deslop <paths>'
```

- Model `opus`, effort `low` — sabit.
- `run_in_background: true`, `timeout: 600000`.
- Yollar `<repo>`'ya göreli, boşluklu yol tırnaklı.
- Eşzamanlı en fazla 6 oturum; fazlası dalgalar hâlinde. Hiçbir grup atlanmaz.
- Grup başına `TaskCreate`, biten `TaskUpdate`.

## 5. Doğrula

`git diff --stat` + rapordaki her dosya için `git diff -- <path>`.

- `CHANGED` diff'te yoksa rapor yanlıştır.
- `CLEAN`/`SKIPPED` dosyasında değişiklik varsa geri alınır.
- Kod, `msgid`, i18n anahtarı, link hedefi, attribute değişmişse o hunk geri alınır.
- `SOURCES: FAILED` dönen grup yapılmamıştır, tekrar koşulur.
- Oturum kesilmişse raporda görünmeyen dosyalar tekrar gönderilir.

## 6. Rapor

Alt oturum çıktısında `SOURCES:` ile başlayan blok ayıklanır, hook gürültüsü atılır. Gruplar
birleştirilir, tekrarlar ayıklanır.

```
deslop — <N> dosya, <M> dosyada <T> düzeltme

<path> (<n>)
  - <desen> | "<önce>" -> "<sonra>"

Temiz: <path>...
Kapsam dışı: <path> — <sebep>
Kesilen iddia: <path>:<satır> — "<alıntı>"
Doğrulama: <sonuç>
```

Sonra `AskUserQuestion`: `["Değişiklikleri bırak", "Geri al", "Belirli dosyaları geri al"]`.

Commit yapılmaz — teslimat `commit` skill'inin işidir.

Başka bir skill'den çağrıldıysa (ör. `commit` 3b) kapanış sorusu sorulmaz; rapor çağırana döner,
kararı o verir.
