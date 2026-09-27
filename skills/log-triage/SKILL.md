---
name: log-triage
description: Logları pencere×açı paralel analiz edip doğruladığı sorunları Plane'e issue açar.
when_to_use: Trigger — "logları analiz et", "son N saatte sorun var mı", "log triage", "loglardan issue çıkar", "/log-triage <proje> <süre>". Bir diji-logs projesinin son N saatlik logu (hata + performans + iş akışı + log hijyeni) taranıp doğrulanan sorunlar Plane'e taşınacaksa. Tüm projelere uyar; değişen yalnız hedef proje ve Plane proje UUID'si.
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Skill, Task, TaskCreate, TaskUpdate
---

# Log Triage — Pencere × Açı Paralel Log Analizi → Plane Issue

```
Hazırlık (Claude)     : log çek → N saat → M pencere → /tmp (stratified)
SUB-AGENT (tek faz)   : her pencere × her açı = paralel sub-agent (M×A sub-agent)
Claude orchestration  : dedup + canlı doğrulama → katmanlı rapor
                        → BULGULARI TABLO HALİNDE SUN (onaydan ÖNCE — zorunlu)
                        → Plane eşleştirme → katman katman onay → sıralı issue create
```

- Tek sub-agent fan-out'u = analiz. Issue açma sub-agent'a DEVREDİLMEZ: Claude sırayla, her create ayrı plane-cli komutu.
- Başta görev listesi aç (çek / sub-agent analiz / dedup+doğrula / tablo+onay / issue create); ilerledikçe güncelle.

## Adım 0 — Argümanlar

`$1`=proje, `$2`=süre (örn `1h`, `3h`), `$3`=pencere sayısı.

1. Proje: `$1` → yoksa `AGENTS.md`'deki diji-logs projesi → yoksa listeyi çek, soru aracıyla seçtir:
   ```bash
   "$HOME/Desktop/Git/personal-assistant/skills/diji-logs/scripts/query.sh" projects
   ```
2. Süre: yoksa soru aracıyla sor (önerilen `1h`). Dakikaya çevir (`1h`→60, `3h`→180).
3. Pencere sayısı: varsayılan 4. Pencere = `süre / pencere_sayısı` dk.
4. env: varsayılan `prod`; `projects` çıktısında proje hem prod hem dev ise sor.

Token/erişim `~/.config/diji-logs/env`'de, `query.sh` otomatik okur — sorma. Detay: `diji-logs` skill.

## Adım 1 — Pencereleri çek

```bash
SCR="<scratchpad>/logwin"   # oturum scratchpad'i altında
"$HOME/Desktop/Git/personal-assistant/skills/log-triage/scripts/fetch_windows.sh" \
  "<proje>" "<env>" <toplam_dk> <pencere_sayısı> "$SCR"
```

- M eşit pencere, relative offset (P1 = en yeni, son pencere = en eski). Çıktı `$SCR/P1.json ... PM.json`, stratified: ERROR/WARN ham, DEBUG/SQL aggregate, slow query. Satır sayımları stdout'a basılır.
- Ham dump kullanma (limit 1000'i aşar, agent context'ini boğar).
- `run_in_background: true` ile çalıştır, `task-notification` bekle.

## Adım 2 — SUB-AGENT: pencere × açı analiz

Tek fazda `M × A` paralel sub-agent. 4 standart açı (gerekirse projeye özel ekle):
- **hata** — gerçek hatalar (booking/payment/provider/sync fail, exception, constraint, 5xx); ErrRecordNotFound (rows:0+boş error) = SAHTE, ayrı işaretle; zincirleme (aynı trace_id).
- **perf** — sql_agg tekrar/N+1, slow_query, debug_msg_agg hot-loop/spam, cache eksikliği.
- **akis** — booking status akışı, fiyat mismatch (provider≠stored), provider tutarsızlık (örn order CLOSED ama bilet canlı), markup fallback.
- **hijyen** — yanlış log seviyesi (sahte ERROR), log spam/hacim, PII/credential sızıntısı (örn PostgreSQL constraint `error.Detail`'de email/telefon), auth anomalisi (403/401).

`references/subagent_template.md`'yi pencere listesi + dosya yolu + (gerekirse) özel açı ile doldurup sub-agent'ları spawn et; brief metinleri `references/angles.md`. Her sub-agent: etiket `<P>:<açı>`.

Tüm sub-agent sonuçlarını topla (hata/boş döneni yeniden spawn et); her `{window, angle, text}`'i ayrı `.md`'ye yaz.

## Adım 3 — Dedup + canlı doğrulama

1. Dedup: farklı pencerelerde tekrarlayan sorun = tek bulgu; "N pencerede görüldü → sistemik" notu, sayımları topla.
2. Kritik bulguları `diji-logs query.sh` canlı sorgusuyla doğrula (hâlâ aktif/gerçek mi; örn mismatch sayısı, constraint hatası, PII alanı). Doğrulanamayanı düşür veya "doğrulanamadı" işaretle.
3. Katmanla:
   - **Katman 1 — Kritik**: veri kaybı, para/booking tutarsızlığı, güvenlik (PII), acil.
   - **Katman 2 — Yüksek/Orta**: provider/sync fail, altyapı eksikliği.
   - **Katman 3 — Performans**: N+1, cache, slow query, index.
   - **Katman 4 — Log Hijyeni**: yanlış seviye, spam, credential log, frontend gürültü.

## Adım 4 — Bulguları tablo halinde sun (onaydan ÖNCE, zorunlu)

Onay sorusundan önce tüm bulguları konuşmada tablo olarak listele; kör onay yasak. Katman başına ayrı tablo, kolonlar en az: # / Sorun / Kanıt(sayım) / Kapsam(tenant·provider·booking) / Örnek trace_id / Kök neden / Plane'de var mı.

## Adım 5 — Plane eşleştirme (`log-triage` label)

Skill'in açtığı tüm issue'lar `log-triage` label'ı taşır; eşleştirme yalnız bu label'lı issue'larla yapılır.

1. Label'ı bul/oluştur (idempotent), UUID'sini sakla:
   ```bash
   plane-cli --json label list --project <UUID>     # "log-triage" var mı?
   # yoksa:
   plane-cli --json label create "log-triage" --project <UUID> --color "#e11d48"
   ```
2. Label'lı issue'ları çek. `issue list` `labels` alanını hep `[]` döner — ona asla dayanma (yoksa her çalıştırmada duplicate açılır):
   - Tercih: `issue list` label filtresi destekliyorsa kullan (`plane-cli issue list --help` ile doğrula).
   - Fallback: `issue list`'ten aday ID'leri al, her birini `plane-cli --json issue get <uuid> --project <UUID>` ile çek; label UUID'si `get`'in `labels` listesindeyse `log-triage` etiketlidir.
3. Bulguları bu label-doğrulanmış liste başlıklarıyla karşılaştır; tablodaki "Plane'de var mı?" = "YOK" veya `PROJ-N`. Eşleşene yeni issue açma; gerekirse mevcut issue'ya yorum/güncelleme öner.

## Adım 6 — Katman katman onay

Katman başına bir soru (soru aracı, `multiSelect: true`): "Hangileri için issue açayım?" Seçenekler = katmandaki bulgular (label kısa, description'da kanıt+öncelik). Kullanıcı "hepsini aç" derse soruları atla. Onay/seçim her zaman soru aracıyla; düz metin soru yok.

## Adım 7 — Onaylananları sırayla aç

1. State UUID'si (genelde "Başlanmadı"/unstarted): `plane-cli state list --project <UUID>`.
2. `log-triage` label UUID'si (Adım 5) hazır olsun.
3. Her bulgu için HTML'i `references/issue_template.md` zorunlu yapısına göre üret (tüm bölümler, ≥1 PII-maskeli ham log örneği, Tespit Bağlamı; veri yoksa "tespit edilemedi"). `html.escape` ile escape edip dosyaya yaz; create dosyadan zorunlu.
4. `scripts/create_issue.sh` ile sırayla aç:
   ```bash
   "$HOME/.../log-triage/scripts/create_issue.sh" \
     "<proj_uuid>" "<state_uuid>" "<priority>" "<html_dosyası>" "<başlık>" "<label_uuid>"
   ```
   - 6. argüman (label UUID) boş bırakılmaz; her issue `log-triage` label'ı alır.
   - Başlığa `[log-triage]` veya başka tag prefix'i EKLEME; başlık = yalnız sorun (örn `Ödeme callback POST body maskesiz loglanıyor — KVKK/PCI`).
   - Priority: Katman1→`urgent`/`high`, Katman2→`high`/`medium`, Katman3→`medium`, Katman4→`medium`/`low`; güvenlik içerenler `high`.
5. `PROJ-N OK` = label eklendi. Teyit gerekirse `issue get <uuid>` ile bak (`list` ile değil). `FAIL` olursa: `plane-cli issue label <uuid> --project <UUID> --add <label_uuid>`.
6. Açılan `PROJ-N`'leri katman tablosu olarak özetle.

## İlgili

- `diji-logs` skill — VictoriaLogs/LogsQL sorgu katmanı.
- `plane-cli` skill — issue CRUD.
- `references/subagent_template.md`, `references/angles.md`, `references/issue_template.md`.
