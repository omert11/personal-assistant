# Zammad Helpdesk

Diji destek sistemi `support.diji.tech` üzerinde Zammad 6.5.2 (Docker compose). Sunucu erişim bilgileri `production.md`'de (Zammad bölümü).

## zammad-cli (Okuma + Ticket CRUD)
- Binary kurulu, env tanımlı (`ZAMMAD_URL`, `ZAMMAD_TOKEN`). Her zaman `--json` ile çağır.
- Yapabildikleri: `ticket` (search/list/get/create/update/article add), `org`, `user`, `system` (groups/states/priorities — sadece **listeleme**), `tags`.
- Yapamadıkları: priority/state oluşturma, object/screen yönetimi. Bunlar için REST API veya Rails console gerekir.
- Detaylı kullanım: `zammad-cli` skill'i.

## REST API ile Yönetim
Token `admin.object` iznine sahip. `curl` ile:
- **Priority CRUD**: `POST/PUT /api/v1/ticket_priorities` (name, active, ui_order, ui_color: `high-priority`, default_create).
- **State CRUD**: `POST /api/v1/ticket_states` (name, state_type_id — instance-specific, console'dan bulunur).
- **Ayarlar**: `GET /api/v1/settings`, makro/tetikleyici/SLA: `/api/v1/{macros,triggers,slas,overviews}`.

## Object/Screen Yönetimi — Rails Console ŞART
**Core alanlar** (`priority_id`, `state_id` vb.) `editable: false` taşır. Bunların `screens` (rol×ekran görünürlük) ayarı **REST API'den DEĞİŞTİRİLEMEZ**:
- `name` gönderince → `422 Name attribute is not editable`
- `name` göndermeyince → `500 undefined method 'downcase'/'match?' for nil`

Tek yol Rails console (validation atlanır):
```ruby
a = ObjectManager::Attribute.get(object: 'Ticket', name: 'priority_id')
s = a.screens
s['create_middle']['ticket.customer'] = { 'null' => false, 'item_class' => 'column' }  # ticket AÇARKEN
s['edit']['ticket.customer'] = { 'null' => false }                                      # DETAYDA düzenleme
a.screens = s
a.save!(validate: false)
ObjectManager::Attribute.migration_execute   # canlıya uygula
Rails.cache.clear
```
- screens rolleri: `ticket.agent`, `ticket.customer`. `null: false` = gösterilir-zorunlu değil.
- Frontend'de görünmesi için kullanıcı hard refresh (Ctrl+Shift+R); gerekirse `docker compose restart zammad-railsserver`.

## Rails Console Çalıştırma — database.yml Workaround (ÖNEMLİ)
`docker exec ... rails runner "..."` doğrudan **çalışmaz**: `config/database.yml` yok hatası verir (Zammad bu dosyayı sadece container init'inde env'den üretir, manuel exec'te yok).

Çözüm — container'da POSTGRESQL_* env'leri hazır, geçici dosya yaz/sil:
```bash
sudo docker exec zammad-zammad-railsserver-1 sh -c '
cat > /opt/zammad/config/database.yml <<EOF
production:
  adapter: postgresql
  database: $POSTGRESQL_DB
  pool: 50
  encoding: utf8
  username: $POSTGRESQL_USER
  password: $POSTGRESQL_PASS
  host: $POSTGRESQL_HOST
  port: $POSTGRESQL_PORT
EOF'
sudo docker exec zammad-zammad-railsserver-1 rails runner "..."
sudo docker exec zammad-zammad-railsserver-1 rm -f /opt/zammad/config/database.yml
```

## Priority Skalası
2026-06-08'de 3→5 seviyeye çıkarıldı (hepsi Türkçe): `1 düşük` / `2 normal` (default) / `3 yüksek` / `4 çok yüksek` / `5 acil`.
Müşteriler (ticket.customer) ticket açarken VE detayda önceliği seçip değiştirebilir (screens'e eklendi).

## Dikkat
- Priority ada göre değil **`priority_id` (sayı)** ile referanslanır — ad değiştirmek makro/SLA/tetikleyiciyi bozmaz. Yine de değiştirmeden önce kontrol et.
- Müşteri önceliği serbest seçebildiği için herkesin "5 acil" seçme eğilimi olabilir; gerekirse tetikleyici ile sınırla.
