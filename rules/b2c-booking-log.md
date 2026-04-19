# B2C Booking Log Analizi

## Log Dosyaları
- Dizin: `server/logs/`
- `debug.log` (.1-.5 rotasyonlu) — Genel Django logları
- `diji.csv` (+ tarihli: `diji.csv.YYYY-MM-DD`) — Uygulama logları
- `flight.csv`, `hotel.csv`, `tour.csv` (+ tarihli) — Modül bazlı loglar

## DB Modelleri
- `Booking` — `basket__reference` ile filtrele (`pnr_code` BookingItem'da)
- `BookingItem` — `pnr_code`, `airline_pnr_code`
- `UserBookingBasket` — `reference` (PK), `status`, `errors` (related_name)
- `AppLog` — `trace_id` ile basket ref veya booking id ara, `trace_type` ile tipi belirle
- `ErrorMessage` — `basket.errors` üzerinden hata mesajları

## Booking Status Akışı
- `READY → PREBOOKED → PAYPROCESSING → PROCESSING → SUCCESS`
- Hata: `FAIL`, `CANCEL`, `NOTCONTINUED`
- `PAYPROCESSING`: Ödeme bekleniyor (3D Secure dahil)
- `PROCESSING`: Ödeme alındı, bilet/voucher kesilme aşaması

## Logger Hiyerarşisi
- `diji.<modul>.api.gateway.prebook` — Ön rezervasyon
- `diji.<modul>.api.gateway.booking` — Booking status kontrolü
- `diji.common.api.gateway.payment` — Ödeme durumu (FAILED/SUCCESS)
- `diji.common.api.gateway.finalize` — Finalize süreci
- `diji.<modul>.booking` — Status değişiklikleri
- `diji.<modul>.notifications.mail` — Mail bildirimleri
- `diji.<modul>.notifications.sms` — SMS bildirimleri

## Flight Özel
- `BookingItem` — `route_index` ile güzergah sırası, `item_id` ile unique tanım
- `Ticket` — `ticket_number`, `status` (READY/SUCCESS/CANCEL/REFUND)
- `Segment` — `flight_number`, `departure_date/time`, `arrival_date/time`, `marketing_airline`, `operating_airline`
- `diji.flight.api.gateway.price_check` — Fiyat kontrolü logları
- `diji.flight.api.gateway.db.booking` — Booking/item/segment/ticket oluşturma logları
- NOT: Prebook her tekrar denemede önceki booking'i silip yenisini oluşturur ("Deleted previous booking")

## Bilinen Sorunlar
- Duplicate finalize çağrısı SUCCESS booking'i FAIL'e çevirebilir (race condition)
- PAYPROCESSING'de takılı kalan booking'ler: BookingStatusTask'ın temizlemediği durumlar olabiliyor
- Ödeme FAILED geldiğinde bazen FAIL'e düşmeyip PAYPROCESSING'de kalabiliyor
- SMS gönderimi NoneType hatası verebiliyor (telefon numarası veya SMS provider eksikliği)
