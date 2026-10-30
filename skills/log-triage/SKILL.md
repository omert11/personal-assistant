---
name: log-triage
description: Logları pencere×açı paralel analiz eder, doğruladığı sorunları sohbette raporlar.
when_to_use: Trigger — "logları analiz et", "son N saatte sorun var mı", "log triage", "loglardan sorun çıkar", "/log-triage <proje> <süre>". Bir diji-logs projesinin son N saatlik logu (hata + performans + iş akışı + log hijyeni) taranıp doğrulanan sorunlar raporlanacaksa. Tüm projelere uyar; değişen yalnız hedef proje.
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Skill, Task, TaskCreate, TaskUpdate
---

# Log Triage — Pencere × Açı Paralel Log Analizi → Sohbet Raporu

```
Hazırlık (Claude)     : log çek → N saat → M pencere → /tmp (stratified)
SUB-AGENT (tek faz)   : her pencere × her açı = paralel sub-agent (M×A sub-agent)
Claude orchestration  : dedup + canlı doğrulama → katmanlı rapor
                        → bulgu tablosu + bulgu başına ayrıntılı rapor (sohbete)
```

- Tek sub-agent fan-out'u = analiz. Rapor yazımı sub-agent'a DEVREDİLMEZ: Claude yazar.
- Başta görev listesi aç (çek / sub-agent analiz / dedup+doğrula / rapor); ilerledikçe güncelle.

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

## Adım 4 — Bulgu tablosu

Tüm bulguları sohbette katman başına ayrı tablo olarak listele; kolonlar en az: # / Sorun / Kanıt(sayım) / Kapsam(tenant·provider·booking) / Örnek trace_id / Kök neden / Öncelik.

- Öncelik: Katman1→`urgent`/`high`, Katman2→`high`/`medium`, Katman3→`medium`, Katman4→`medium`/`low`; güvenlik içerenler `high`.

## Adım 5 — Bulgu başına ayrıntılı rapor

Tablodan sonra her bulgu için `references/finding_template.md` yapısında markdown rapor yaz (sohbete; katman sırasıyla, katman içinde öncelik sırasıyla).

- Tüm bölümler zorunlu; ≥1 PII-maskeli ham log örneği; veri yoksa "tespit edilemedi".
- Başlık = yalnız sorun (örn `Ödeme callback POST body maskesiz loglanıyor — KVKK/PCI`), tag prefix'i yok.

## İlgili

- `diji-logs` skill — VictoriaLogs/LogsQL sorgu katmanı.
- `references/subagent_template.md`, `references/angles.md`, `references/finding_template.md`.
