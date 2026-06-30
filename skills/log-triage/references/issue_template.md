# Issue Template (zorunlu bağlam yapısı)

Açılan her issue, **sonraki oturumlara doğru context taşımalı** — kişi/AI issue'ya bakınca
sıfırdan log kazmadan sorunu anlamalı. Bu yüzden her issue **aşağıdaki tüm bölümleri** içerir
ve **en az 1 ham log örneği** taşır.

> Eksik bağlamlı issue (sadece "X hatası var") yasak. Her bölüm doldurulmalı; veri yoksa
> "tespit edilemedi" yaz, atlanmaz.

## Zorunlu bölümler (HTML, sırayla)

| Bölüm | İçerik | Neden |
|---|---|---|
| `<h2>Sorun</h2>` | 1-2 cümle: ne oluyor, neden problem | Hızlı kavrama |
| `<h3>Kapsam</h3>` | tenant / agency / provider / booking ref / etkilenen endpoint | Tekrarlamak/lokalize etmek için |
| `<h3>Kanıt — log örneği</h3>` | **EN AZ 1 ham log satırı** (maskeli), `_time`, `_msg`, ilgili alanlar | Sonraki oturum doğrulayabilsin |
| `<h3>Sayım / Sıklık</h3>` | kaç olay / hangi pencere / X saatte toplam (canlı doğrulanmış) | Önceliklendirme + sistemik mi anlamak |
| `<h3>Örnek trace_id</h3>` | ≥1 trace_id (varsa) — drill-down için | Geçmişe gidip trace izlemek |
| `<h3>Kök Neden Hipotezi</h3>` | en olası neden + (varsa) ilgili kod/tablo/constraint adı | Çözüme başlangıç |
| `<h3>Öneri</h3>` | somut düzeltme yönü | Aksiyon |
| `<h3>Tespit Bağlamı</h3>` | "log-triage skill, <proje>, <tarih-aralığı>, pencere <P>" | Provenance — ne zaman/nasıl bulundu |

## Log örneği kuralı (KRİTİK)

- **PII MASKELE**: email → `***@***`, telefon → `+90**********`, token → `<token-prefix>...`.
  Ham PII'yı issue'ya **yazma** (issue'nun kendisi PII sızıntısı olmasın).
- Log satırını `<pre><code>...</code></pre>` içine koy.
- Sayı/UUID dolu uzun satırları kısalt ama `_msg` + ayırt edici alanları (`error.Code`,
  `error.ConstraintName`, `provider`, `sql` özeti) koru.
- Örnek 1 satır yetmiyorsa (zincirleme hata) 2-3 satır ver, fazlası gürültü.

## HTML üretimi (html.escape zorunlu)

İçerik `<`, `"`, `()` içerdiği için inline plane-cli create bozulur → her zaman Python
`html.escape` ile escape edip **dosyaya yaz**, `create_issue.sh` ile dosyadan oluştur.

```python
import html, os
def esc(s): return html.escape(s)

# log örneği zaten maskeli string olarak gelir; esc ile HTML-safe yapılır
body = f"""<h2>Sorun</h2><p>{esc(sorun)}</p>\
<h3>Kapsam</h3><p>{esc(kapsam)}</p>\
<h3>Kanıt — log örneği</h3><pre><code>{esc(log_ornegi)}</code></pre>\
<h3>Sayım / Sıklık</h3><p>{esc(sayim)}</p>\
<h3>Örnek trace_id</h3><p>{esc(trace)}</p>\
<h3>Kök Neden Hipotezi</h3><p>{esc(kok_neden)}</p>\
<h3>Öneri</h3><p>{esc(oneri)}</p>\
<h3>Tespit Bağlamı</h3><p>{esc(provenance)}</p>"""
open(f"{html_dir}/{slug}.html","w").write(body)
```

## Örnek (doldurulmuş, maskeli)

```html
<h2>Sorun</h2>
<p>Transfer sync worker prebook süresi geçmiş booking'leri expired yazmaya çalışıyor; DB check
constraint chk_booking_status reddediyor (PG 23514) — sonsuz retry loop.</p>
<h3>Kapsam</h3>
<p>tenant: Zenrota B2C (agency 70078472) · 4 booking: TRN-2026-000010/018/035/040 · hepsi UNPAID</p>
<h3>Kanıt — log örneği</h3>
<pre><code>_time=2026-06-30T08:08:16Z level=ERROR _msg="gorm query error"
error.Code=23514 error.ConstraintName=chk_booking_status
error.Detail=Failing row contains ( ... ***@*** , +90********** , "&lt;not-maskeli&gt;" ... )
sql=UPDATE "transfer_bookings" SET status='expired',sync_disabled=true WHERE id='27cfd62e...'</code></pre>
<h3>Sayım / Sıklık</h3>
<p>4 pencerede de aktif (sistemik). Son 1 saatte ~50+ olay; 08:08'de canlı doğrulandı.</p>
<h3>Örnek trace_id</h3>
<p>(worker job — trace_id yok; booking_id 27cfd62e ile izlenir)</p>
<h3>Kök Neden Hipotezi</h3>
<p>chk_booking_status constraint expired terminal state'ine izin vermiyor; sync_disabled da
yazılamadığı için worker her ~2dk aynı kayıtları tekrar deniyor.</p>
<h3>Öneri</h3>
<p>Migration: constraint'e expired ekle veya worker hedef status'unu uyumla. 4 booking manuel
terminal state'e al.</p>
<h3>Tespit Bağlamı</h3>
<p>log-triage skill · b2b.b2btravel.pro · 2026-06-30 06:52–07:52 UTC · pencere P1-P4</p>
```

> Bu yapı, issue'yu 3 ay sonra açan birinin (veya AI'ın) tekrar log kazmadan sorunu anlamasını,
> trace'i izlemesini ve doğrulamasını sağlar.
