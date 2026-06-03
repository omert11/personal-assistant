---
name: diji-log-search
description: Diji b2c basket'inin tum yasam dongusunu prod loglarindan cikarir, sorunu raporlar.
when_to_use: Trigger — "su hata alindi son loglara bak", "bu hata mesajini arastir", "<ref> sepetini incele", "basket lifecycle", "odeme neden basarisiz", "provider loglari", "/diji-log-search". Hata mesaji/ekran goruntusu verilince find modu ilgili basket'i bulur. Diji tabanli b2c Django projelerde (CLAUDE.local.md'de prod SSH/path tanimli) AppLog/basket log analizi gerektiginde.
arguments: reference mode
allowed-tools: Bash, Read, Grep
---

# Diji Log Search — Basket Lifecycle Analyzer

Bir diji-tabanli b2c Django projesinde (b2c travel platformlari) bir **basket reference**'in
tum yasam dongusunu prod `AppLog` tablosundan cikarir, ozetler ve sorunu teshis eder.
Kullanici ref vermeden "su hata, son loglara bak" derse, ilgili islemi **kendisi bulur**.

> **Marka/proje adi kullanma**: Cikti ve kodda proje markasi (sirket/urun adi) GECMEZ.
> Domain bilgisi her zaman calisilan projenin `CLAUDE.local.md`'sinden okunur — hardcode etme.

## Mimari (neden boyle)

- Agir sorgu mantigi `scripts/diji_log_search.py` icinde. Inline `manage.py shell -c` quoting
  `$ ^ ~` ve girinti yuzunden kirilgan → script **scp** edilir, `manage.py shell < dosya` ile calisir.
- Parametreler **env var** ile gecer (BL_REF, BL_MODE, ...) — quoting derdi yok.
- Cikti **/tmp**'e yazilir (canli JWT/credential icerebilir → repo disi). **Zed ile ACILMAZ**;
  rapor konusmada sunulur.

## Adim 0 — Ortami CLAUDE.local.md'den oku

Calisilan projenin `CLAUDE.local.md`'sindeki **"Sunucu Ortamlari"** tablosundan al:
- SSH komutu (orn `ssh -i ~/.ssh/<key>.pem ubuntu@<ip>`)
- Prod path (`.../server` ust dizini — `manage.py`'nin oldugu yer)
- Hangi ortam (Production / Stage / Dev) — kullanici belirtmezse **Production** varsay, ama dogrula.

`AskUserQuestion` ile ortami teyit et (Production/Stage/Dev) — yanlis ortamda log aramak bos doner.
venv her zaman `.venv/bin/python`.

## Adim 1 — Modu belirle

| Kullanici ne der | BL_MODE | gerekli env |
|---|---|---|
| "<ref> sepetini incele", "yasam dongusu" | `lifecycle` | BL_REF |
| "provider/tedarikci loglari", "paximum request" | `provider` | BL_REF |
| "odeme loglari", "3D neden basarisiz" | `payment` | BL_REF |
| "ham loglar", "her seyi dok" | `raw` | BL_REF |
| **"su hata mesaji geldi" / ekran goruntusu** (ref YOK) | `find` | **BL_QUERY** |
| "son loglarda genel hata var mi" (ref YOK) | `diagnose` | — |

### find modu — ref'siz teshisin EN HIZLI yolu

Kullanici bir **hata mesaji** (ekran goruntusu/metin) veya **hata kodu** (`COMxxx`) verdiginde:
1. Mesaj bir ceviri olabilir → Ingilizce orijinalini `grep -rn "<TR metin>" locale/*/LC_MESSAGES/*.po` veya
   `core/messages/messages.py` ile bul (msgid). find modu hem TR metni hem kodu hem `data` kolonunu arar.
2. `BL_MODE=find BL_QUERY='<mesaj veya COMxxx>'` calistir. Kod verilirse otomatik Ingilizce
   metnine cozulup onunla da aranir; eslesen basket reference'lari listelenir.
3. Cikan basket'i `BL_MODE=lifecycle BL_REF=<ref>` ile incele.

> Bu, "mesaj → kod → basket → trace" zincirini tek komuta indirir (elle script yazma).

**Kurallar:**
- **Arastirma = O GUNUN loglari** ama tek gun KOR NOKTA yaratir (kullanici dunku ekran
  goruntusu verebilir). Bu yuzden find/diagnose varsayilani **`BL_DAYS=2`** (dun+bugun).
  Daha geriye: `BL_DAYS=<n>`. "Son X dk" istenirse `BL_SCOPE=since BL_SINCE_MIN=<dk>`.
- Ekran goruntusundeki URL'den ipucu cikar (orn `/otel/odeme/o-4972/...` → otel, offer id;
  ama `o-4972` basket reference DEGIL — `UserBookingBasket` PK'si `reference` alanidir).

### ORTAM KORLUGU — find 0 dondurunce DUR, panik yapma

Marka adi (ekrandaki logo) ortami BELIRLEMEZ — dev/stage de ayni markayi gosterir.
"API'den gelen ... sayfasi", "test", staging URL gibi ipuclari **non-prod** sinyalidir.
find/diagnose bir ortamda 0 donduyse:
1. **Ham CSV fallback otomatik calisir** (find modu): AppLog import gecikmisse (LogReaderTask
   30 dk'da bir) hata DB'de yoktur ama CSV'dedir. Cikti "ham CSV eslesmeleri" verir.
2. Yine 0 ise **DIGER ORTAMI tara**. CLAUDE.local.md Sunucu Ortamlari tablosundaki her
   path icin `BL_LOG_DIR` set edip tekrar calistir (ayni SSH host, farkli dizin):

```bash
# Ayni sunucuda 3 ortam — her birinin server/logs'unu BL_LOG_DIR ile dene
for ENVDIR in \
   /home/ubuntu/git/production/<prod-dir> \
   /home/ubuntu/git/dev/<dev-dir> \
   /home/ubuntu/git/dev/<stage-dir>; do
  $SSH "cd $ENVDIR && BL_MODE=find BL_QUERY='<kod/mesaj>' BL_DAYS=3 \
        BL_LOG_DIR=$ENVDIR/server/logs .venv/bin/python manage.py shell < /tmp/diji_log_search.py 2>/dev/null \
        | grep -E 'eslesen|ham CSV|basket ref|Incele'"
done
```

3. En hizli kestirme: hata kodu/metni **tum ortamlarin loglarinda** dogrudan grep:
   `$SSH 'grep -rl -F \"<KOD>\" /home/ubuntu/git/*/*/server/logs 2>/dev/null'` →
   hangi ortamda gectigini gosterir, sonra o ortamda lifecycle calistir.

## Adim 2 — Script'i gonder ve calistir

```bash
# Degiskenleri CLAUDE.local.md'den doldur:
SSH="ssh -i ~/.ssh/<key>.pem ubuntu@<ip>"
SCP="scp -i ~/.ssh/<key>.pem"
PROD="/home/ubuntu/git/<env>/<dir>"          # manage.py dizini
REF="<basket-ref>"; MODE="lifecycle"          # veya diagnose (REF bos)

$SCP -o StrictHostKeyChecking=no \
  "$CLAUDE_PLUGIN_ROOT/skills/diji-log-search/scripts/diji_log_search.py" \
  ubuntu@<ip>:/tmp/diji_log_search.py

OUT="/tmp/diji_${REF:-diagnose}_${MODE}.txt"
$SSH -o StrictHostKeyChecking=no \
  "cd $PROD && BL_REF='$REF' BL_MODE='$MODE' .venv/bin/python manage.py shell < /tmp/diji_log_search.py 2>/dev/null" \
  > "$OUT"
```

> Uzun surebilir → `run_in_background: true` ile calistir, `task-notification` bekle.
> Cikti BUYUK olabilir (raw/provider) → `wc -l` + `head` ile kontrol et, tamamini Read etme.

## Adim 3 — LogReader sagligini oku (ZORUNLU)

Script ciktisinin **basinda** `# LOGREADER SAGLIK KONTROLU` blogu var. Kontrol et:
- "CSV, DB'den ~N sn daha yeni" / "import edilmemis olabilir" → loglar **eksik** olabilir.
  Kullaniciya bildir; gerekirse prod'da `LogReaderTask` tetiklemeyi oner
  (`async_to_sync(LogReaderTask().task)()` ya da basket detay sayfasini acmak import'u tetikler).
- "cursor GELECEK tarihte" → **cursor poisoning** suphesi; import durmus olabilir, raporla.
- "OK: import guncel" → devam.

**Loglar okunmadiysa arastirma zor/eksik olur** — once bunu cozmeden sonuca varma.

## Adim 4 — Raporla

- **lifecycle**: kronolojik ozet + booking/payment/status + son durum yorumu
  (orn "PAYPROCESSING'de takili, 3D callback yok → odeme tamamlanmadi").
- **diagnose**: hata satirlari + tespit edilen basket trace_id'leri → en olasi olani
  `lifecycle` modunda ikinci kez incele, kok nedeni acikla.
- **provider/payment/raw**: ciktinin yerini (`/tmp/...txt`) ve ozet istatistigini ver;
  kullanici isterse ilgili bolumu Read ile ac.

## Env var referansi (script)

| Var | Anlam | Default |
|---|---|---|
| `BL_REF` | basket reference | (find/diagnose'da bos) |
| `BL_MODE` | lifecycle\|provider\|payment\|raw\|find\|diagnose | lifecycle |
| `BL_QUERY` | find modu: hata mesaji metni veya COMxxx kodu | — |
| `BL_WINDOW_H` | usersession +/- saat penceresi | 3 |
| `BL_SCOPE` | find/diagnose: today(=DAYS gun)\|since | today |
| `BL_DAYS` | find/diagnose: kac gun geriye tara | 2 |
| `BL_SINCE_MIN` | scope=since: son N dk | 120 |
| `BL_LIMIT` | find/diagnose: max satir | 50 |
| `BL_LOG_DIR` | ham CSV fallback/ortam: server/logs dizini | (otomatik tespit) |

## Onemli kurallar (ozet)

1. **Marka/proje adi yok** — domain her zaman `CLAUDE.local.md`'den.
2. **Arastirma = o gunun loglari** (diagnose default scope=today).
3. **Arastirma oncesi logreader durumu kontrol** — loglar okunmadiysa eksik sonuc.
4. **frontend (`diji.common.api.frontend`) HER ZAMAN exclude** (lifecycle).
5. **usersession kalici kullanici oturumu** → +/-3h pencere ile sinirla, yoksa alakasiz
   transaction'lar sizar.
6. **Cikti /tmp'e, Zed acilmaz** — canli credential icerebilir.
