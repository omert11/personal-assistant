---
name: do-deslop
description: Verilen dosyalarda AI yazim izlerini canli kaynaktan okuyup tek tek temizler.
when_to_use: Trigger — `/do-deslop <dosya|glob|dizin>...`. `deslop` skill'inin ayri `claude -p` oturumunda calistirdigi isci taraftir; normal sohbette elle cagrilmaz. Yalniz son kullanicinin gordugu yuzeyleri (README/docs, HTML/template gorunur metin, .po msgstr, i18n deger, kod ici UI string) duzenler.
disable-model-invocation: true
allowed-tools: Read, Edit, Grep, Glob, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/deslop-sources.sh), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/deslop-sources.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/deslop-sources.sh), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/deslop-sources.sh *), Bash(git *), Bash(ls *), Bash(wc *), Bash(file *)
---

# do-deslop — işçi

Girdi: `$ARGUMENTS` — dosya yolu, glob veya dizin listesi.

Başka görev/öneri yok. `deslop` çağrılmaz, yeni `claude -p` oturumu açılmaz.

## 1. Kaynaklar

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/deslop-sources.sh
```

Zorunlu kaynak `MISSING` ise (exit 1): `SOURCES: FAILED <key>` yaz ve dur; hafızadan kuralla çalışma. `stale` kabul edilir, rapora yazılır.

## 2. Oku

Önce `${CLAUDE_PLUGIN_ROOT}/skills/do-deslop/references/ai-writing-rules.md` — tamamı.

Sonra `~/.cache/deslop-sources/` altından:

| Zorunlu | İçerik |
|---|---|
| `s2-humanizer.md` | desen kataloğu, `Words to watch`, em dash katılığı |
| `s5-rewrite-rules.md` | before/after düzeltme kalıpları, swap çiftleri |
| `s5-checklist.md` | teslim öncesi liste |
| `s5-ai-tells.md` | tell kataloğu, markup artifact'ları, güvenilmez işaretler |
| `s1-wikipedia-signs.md` | kelime sınıflandırmasında kazanan otorite |

Opsiyonel: `s4-humanise.md` (swap tabloları), `s3-banned-words.md` (üretim tarafı; sayısal
eşikleri bu görevde uygulanmaz).

- `s1` ~200 KB: içerikte arayarak `Words to watch`, `Ineffective indicators`, `Signs of human writing`,
  `Internal formatting` başlıklarını bul, yalnız o bölümleri oku.
- `s2-humanizer.md` ile `s2-humanizer-mirror.md` arasında `metadata.version` büyük olan okunur.
- Kelime kararı okunan metinden verilir, hatırlanandan değil.

## 3. Hedefler

Glob kalıpları genişletilir, dizine inilir. Elenenler: `node_modules/`, `vendor/`, `dist/`,
`build/`, `.venv/`, `.git/`, `*.min.*`, `*.lock`, binary, 1 MB üstü.

Dosya sayısı tavanı yok; örnekleme, "ilk N", "en önemlileri" yasak. Filtreden düşen dosya rapora `SKIPPED`.

## 4. Kapsam

### Tam dosya

| Sınıf | Kapsam |
|---|---|
| Dokümantasyon | `README*`, `docs/**/*.md(x)`, kılavuz, SSS |
| Landing | tanıtım HTML |
| Template | `*.html`, `*.jinja`, `*.j2`, `*.twig`, `*.blade.php`, `*.erb`, `templates/**` |
| Çeviri | `*.po` (yalnız `msgstr`), `*.pot`, `*.arb`, `*.strings`, `*.xliff` |
| i18n veri | `locales/**`, `i18n/**`, `translations/**`, `lang/**` — yalnız değerler |
| E-posta | `**/emails/**`, `*.mjml` |
| Store | `fastlane/metadata/**`, açıklama/what's-new |

### Kısmi — kod içi UI string

`t()`, `_()`, `gettext()`, `trans()`, `$t()`, `i18n.t()`; toast/alert/modal metni; form `label`,
`placeholder`, `help_text`, `error_messages`; Django `verbose_name`, `help_text`,
`ValidationError`; empty state ve onboarding metni.

### Dışarıda

Kod mantığı; kod yorumu ve docstring; test, fixture, snapshot; config; `AGENTS.md`,
`.cursorrules`, `.claude/**`, `rules/**`, `skills/**`; CHANGELOG; fenced code block; frontmatter;
link hedefi ve URL; HTML `<script>`/`<style>`, attribute, `class`, `id`; `.po` `msgid` ve `#:`
satırları; i18n anahtarları; alıntı, başlık, özel ad, bahsi geçen (kullanılmayan) ifade.

Şüpheliyse dokunma.

## 5. Yöntem

### Toplu değiştirme yasak

`sed -i`, `awk`, `perl -pi`, `tr`, script ile replace ve tümünü-değiştir (`replace_all`) yasak; her geçişi toplu değiştirme yok.

### Dosya başına

1. Dosyayı baştan sona oku (büyükse parça parça, ama tamamı); içerikte arayıp atlama yok.
2. Metinde gerçekten bulunan desenleri çıkar.
3. Her adayı tek tek karara bağla: iz mi, yanlış pozitif mi. Karar kümelenmeye dayanır; tek işaret yetmez.
4. Her düzeltme ayrı bir düzenlemedir.
5. Düzeltmeleri çeşitlendir; aynı kuralı her örneğe mekanik uygulama.
6. Bitince sor: bariz AI kalan ne var, kaynakta olmayan bir şey yazdım mı.

### Bütünlük

- Olgu, isim, sayı, tarih, alıntı, atıf eklenmez ve değişmez.
- Kaynaksız iddia süslenmez: isimlendirilir veya kesilir; kesilen rapora yazılır.
- Yasaklı kelime başka yasaklı kelimeyle değiştirilmez. Doldurma yapılmaz.
- `.po`: format belirteçleri (`%s`, `%(name)s`, `{count}`), HTML etiketleri, kaçış dizileri ve
  çoğul sırası birebir kalır. `#, fuzzy` düzeltme sebebi değildir — o `po-cli`'nin işi.
- HTML: yalnız görünen metin düğümü; DOM, etiket, attribute, `<pre>` içeriği korunur.

### Ses

- Teknik doküman, README, hukuki metin → nötr ve düz. Görüş, birinci şahıs, mizah eklenmez.
- Blog, duyuru, pazarlama → duruş ve ritim serbest, ama olgu eklenmeden.
- Argo, sahte gündelikleşme, uydurma anekdot yasak.
- Dosyanın dili korunur.

## 6. Kontrol

`s5-checklist.md` koşulur. Sonra her değişen dosya için `git diff -- <path>`: yalnız beklenen
satırlar mı değişti. Kod, attribute, `msgid`, anahtar veya link hedefi değiştiyse geri al.
Hedef listesiyle karşılaştır — atlanan var mı.

## 7. Rapor

Çıktı yalnız bu blok; anlatım/giriş cümlesi yok.

```
SOURCES: ok | stale <key>... | FAILED <key>
THRESHOLD-SOURCE: <sayısal eşik hangi kaynaktan uygulandı>

CHANGED:
<path>  (<n> düzeltme)
  - <desen> | "<önce>" -> "<sonra>"

CLEAN:
<path>

SKIPPED:
<path> — <sebep>

CUT:
<path>:<satır> — "<alıntı>"

NOTES:
<kullanıcı kararı gerektiren şey; yoksa none>
```

Her flag birebir alıntı ister. Yüzde/olasılık skoru yok. Düzeltme yoksa da rapor tam formatta.
