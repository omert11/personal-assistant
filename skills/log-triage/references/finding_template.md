# Bulgu Raporu Şablonu (zorunlu bağlam yapısı)

Her bulgu raporu aşağıdaki tüm bölümleri içerir ve en az 1 ham log örneği taşır. Eksik bağlamlı rapor (sadece "X hatası var") yasak; veri yoksa "tespit edilemedi" yaz, bölüm atlanmaz.

## Zorunlu bölümler (markdown, sırayla)

| Bölüm | İçerik |
|---|---|
| `### <#> — <Sorun başlığı>` | başlık + öncelik (`urgent`/`high`/`medium`/`low`) |
| **Sorun** | 1-2 cümle: ne oluyor, neden problem |
| **Kapsam** | tenant / agency / provider / booking ref / etkilenen endpoint |
| **Kanıt — log örneği** | EN AZ 1 ham log satırı (maskeli), `_time`, `_msg`, ilgili alanlar |
| **Sayım / Sıklık** | kaç olay / hangi pencere / X saatte toplam (canlı doğrulanmış) |
| **Örnek trace_id** | ≥1 trace_id (varsa) |
| **Kök Neden Hipotezi** | en olası neden + (varsa) ilgili kod/tablo/constraint adı |
| **Öneri** | somut düzeltme yönü |
| **Tespit Bağlamı** | "log-triage skill, <proje>, <tarih-aralığı>, pencere <P>" |

## Log örneği kuralı

- PII maskele, ham PII yazma: email → `***@***`, telefon → `+90**********`, token → `<token-prefix>...`.
- Log satırı ``` kod bloğu içinde.
- Uzun satırları kısalt; `_msg` + ayırt edici alanları (`error.Code`, `error.ConstraintName`, `provider`, `sql` özeti) koru.
- 1 satır yetmezse (zincirleme hata) 2-3 satır; fazlası yok.

## Örnek (doldurulmuş, maskeli)

````markdown
### 1 — Transfer sync worker expired yazamıyor, sonsuz retry · `high`

**Sorun** — Transfer sync worker prebook süresi geçmiş booking'leri expired yazmaya çalışıyor; DB check
constraint chk_booking_status reddediyor (PG 23514) — sonsuz retry loop.

**Kapsam** — tenant: Zenrota B2C (agency 70078472) · 4 booking: TRN-2026-000010/018/035/040 · hepsi UNPAID

**Kanıt — log örneği**
```
_time=2026-06-30T08:08:16Z level=ERROR _msg="gorm query error"
error.Code=23514 error.ConstraintName=chk_booking_status
error.Detail=Failing row contains ( ... ***@*** , +90********** ... )
sql=UPDATE "transfer_bookings" SET status='expired',sync_disabled=true WHERE id='27cfd62e...'
```

**Sayım / Sıklık** — 4 pencerede de aktif (sistemik). Son 1 saatte ~50+ olay; 08:08'de canlı doğrulandı.

**Örnek trace_id** — (worker job — trace_id yok; booking_id 27cfd62e ile izlenir)

**Kök Neden Hipotezi** — chk_booking_status constraint expired terminal state'ine izin vermiyor; sync_disabled da
yazılamadığı için worker her ~2dk aynı kayıtları tekrar deniyor.

**Öneri** — Migration: constraint'e expired ekle veya worker hedef status'unu uyumla. 4 booking manuel
terminal state'e al.

**Tespit Bağlamı** — log-triage skill · b2b.b2btravel.pro · 2026-06-30 06:52–07:52 UTC · pencere P1-P4
````
