---
name: log-triage
description: Logları pencere×açı paralel analiz edip doğruladığı sorunları Plane'e issue açar.
when_to_use: Trigger — "logları analiz et", "son N saatte sorun var mı", "log triage", "loglardan issue çıkar", "/log-triage <proje> <süre>". Bir diji-logs projesinin son N saatlik logunu kapsamlı (hata + performans + iş akışı + log hijyeni) tarayıp tespit edilen sorunları doğrulayarak Plane'e taşımak gerektiğinde. Tek değişken hedef projedir — akış tüm projelere uyarlanır.
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Workflow, AskUserQuestion, Skill, Task, TaskCreate, TaskUpdate
---

# Log Triage — Pencere × Açı Paralel Log Analizi → Plane Issue

Bir **diji-logs (VictoriaLogs)** projesinin son N saatlik logunu **zaman pencerelerine
böler**, her pencereyi **birden çok açıdan paralel** analiz eder (tek Workflow), bulguları
**dedup + canlı sorgu ile doğrular**, **tablo halinde sunar**, ve kullanıcı onayıyla **Plane'e
issue açar**.

> **Proje-bağımsız.** Değişen tek şey **hedef proje** (`diji-logs` `projects/` listesinden) ve
> Plane proje UUID'si. Akış aynen tüm projelere uyarlanır.

## Mimari (özet)

```
Hazırlık (Claude)     : log çek → N saat → 15dk × M pencere → /tmp (stratified)
WORKFLOW (tek)        : her pencere × her açı = paralel agent (M×A agent, sonnet)
Claude orchestration  : dedup + canlı doğrulama → 3 katmanlı rapor
                        → BULGULARI TABLO HALİNDE SUN (onaydan ÖNCE — zorunlu)
                        → Plane eşleştirme → katman katman onay → sıralı issue create
```

> **Issue açma workflow DEĞİL** — Claude sırayla açar (her create ayrı plane-cli komutu,
> HTML escape gerektiği için). Tek workflow vardır: analiz fan-out'u.

---

## Adım 0 — Argümanları çöz

Skill `$1`=proje, `$2`=süre (örn `1h`, `3h`), `$3`=pencere sayısı (varsayılan 4) alabilir.

1. **Proje hedefi** (argüman + fallback):
   - `$1` verildiyse onu kullan.
   - Yoksa `CLAUDE.local.md`'de tanımlı bir diji-logs proje varsa onu varsay.
   - Hiçbiri yoksa `diji-logs` `projects/` listesini çek, `AskUserQuestion` ile seçtir.
   ```bash
   "$HOME/Desktop/Git/personal-assistant/skills/diji-logs/scripts/query.sh" projects
   ```
2. **Süre** (`$2`): verilmezse `AskUserQuestion` ile sor (önerilen `1h`). Dakikaya çevir
   (`1h`→60, `3h`→180).
3. **Pencere sayısı** (`$3`): varsayılan **4**. Her pencere = `süre / pencere_sayısı` dakika.
4. **env**: genelde `prod`; `projects/` çıktısında aynı proje hem prod hem dev varsa sor.

> diji-logs token/erişimi `~/.config/diji-logs/env`'de — `query.sh` otomatik okur, sorma.
> Detay için `diji-logs` skill'inin SKILL.md'sine bak.

---

## Adım 1 — Pencereleri çek (Hazırlık)

`scripts/fetch_windows.sh` zaman aralığını M eşit pencereye böler ve her pencere için
**stratified** bir JSON dosyası yazar (ERROR/WARN ham + DEBUG/SQL aggregate + slow query).
Bu şekil, tek dosyayı 4 farklı açının ortak okumasını sağlar.

```bash
SCR="<scratchpad>/logwin"   # oturum scratchpad'i altında
"$HOME/Desktop/Git/personal-assistant/skills/log-triage/scripts/fetch_windows.sh" \
  "<proje>" "<env>" <toplam_dk> <pencere_sayısı> "$SCR"
```

- Çıktı: `$SCR/P1.json ... PM.json`. Her dosya başına satır sayımları stdout'a basılır.
- **Uzun sürebilir** → `run_in_background: true` ile çalıştır, `task-notification` bekle.
- Pencere zamanlaması **relative offset** ile yapılır (P1 = en yeni 15dk, son pencere = en eski).

> **Neden ham değil stratified?** 15dk'lık tek pencere ~40k DEBUG satırı tutabilir; ham dump
> hem limit'i (1000) aşar hem agent context'ini boğar. Sinyal (ERROR/WARN) ham, gürültü
> (DEBUG/SQL) aggregate verilir.

---

## Adım 2 — WORKFLOW: pencere × açı paralel analiz

Tek `Workflow` çağrısı. Fan-out birimi **pencere × açı** = `M × A` paralel agent.

**4 standart açı** (gerekirse projeye özel ekle):
- **hata** — gerçek hatalar (booking/payment/provider/sync fail, exception, constraint, 5xx);
  ErrRecordNotFound (rows:0+boş error) = SAHTE, ayrı işaretle; zincirleme (aynı trace_id).
- **perf** — sql_agg tekrar/N+1, slow_query, debug_msg_agg hot-loop/spam, cache eksikliği.
- **akis** — booking status akışı, **fiyat mismatch** (provider≠stored), provider tutarsızlık
  (örn order CLOSED ama bilet canlı), markup fallback.
- **hijyen** — yanlış log seviyesi (sahte ERROR), log spam/hacim, **PII/credential sızıntısı**
  (örn PostgreSQL constraint `error.Detail`'de email/telefon), auth anomalisi (403/401).

Workflow şablonu için **`references/workflow_template.md`** dosyasını oku — oradaki script'i
pencere listesi + dosya yolu + (gerekiyorsa) projeye özel açı ile doldurup `Workflow` ile
çağır. Her `agent()` çağrısı `model: 'sonnet'`, `label: '<P>:<açı>'`, `phase: 'Analyze'`.

> **Token verimliliği**: analiz agent'ları yapılandırılmış log okuma işidir → `sonnet`
> yeter (token-efficiency kuralı). Opus'a düşme.

Workflow `run_in_background` döner; `task-notification` ile sonucu topla. Çıktı truncate
olabilir → tam sonuçları output dosyasından `result` listesini parse edip ayrı `.md`'lere yaz
(her `{window, angle, text}`).

---

## Adım 3 — Dedup + canlı doğrulama (Claude)

1. `M×A` bulguyu oku, **dedup** et: aynı sorun farklı pencerelerde tekrarlıyorsa **tek** bulgu
   (tekrarı "4 pencerede de görüldü → sistemik" olarak not et, sayımları topla).
2. **Canlı sorgu ile doğrula** (en kritik bulgular): `diji-logs query.sh` ile sorunun hâlâ
   aktif/gerçek olduğunu teyit et (örn fiyat mismatch sayısı, constraint hatası, PII alanı).
   Doğrulanamayan/spekülatif bulguyu düşür veya "doğrulanamadı" işaretle.
3. Bulguları **katmanlara** ayır:
   - **Katman 1 — Kritik**: veri kaybı, para/booking tutarsızlığı, güvenlik (PII), acil.
   - **Katman 2 — Yüksek/Orta**: provider/sync fail, altyapı eksikliği.
   - **Katman 3 — Performans**: N+1, cache, slow query, index.
   - **Katman 4 — Log Hijyeni**: yanlış seviye, spam, credential log, frontend gürültü.

---

## Adım 4 — BULGULARI TABLO HALİNDE SUN (onaydan ÖNCE — ZORUNLU)

**Kullanıcı onay sorusunu görmeden ÖNCE** tüm bulguları konuşmaya **tablo** olarak listele.
Kör onay yasak — kullanıcı tabloyu görür, sonra karar verir.

Her katman için ayrı tablo, satırlarda en az: **# / Sorun / Kanıt(sayım) / Kapsam(tenant·
provider·booking) / Örnek trace_id / Kök neden / Plane'de var mı**.

---

## Adım 5 — Plane eşleştirme (`log-triage` label ile)

Bu skill'in açtığı tüm issue'lar **`log-triage` label'ı** taşır. Eşleştirme **yalnız bu label'lı
issue'lar** üzerinden yapılır — böylece alakasız feature/provider issue'ları gürültü yaratmaz,
karşılaştırma sadece bu skill'in geçmiş bulgularına bakar.

1. **Label'ı bul/oluştur** (idempotent):
   ```bash
   plane-cli --json label list --project <UUID>     # "log-triage" var mı?
   # yoksa:
   plane-cli --json label create "log-triage" --project <UUID> --color "#e11d48"
   ```
   Label UUID'sini sonraki adımlar için sakla.
2. **Mevcut label'lı issue'ları çek**: `issue list --project <UUID>` çıktısını **`log-triage`
   label'ına göre filtrele** (her issue'nun `labels` alanında label UUID'si var mı). Free-text
   `issue search` bazı self-hosted instance'larda boş döner → label-filtreli liste daha güvenilir.
3. Her bulguyu bu **filtrelenmiş** liste başlıklarıyla karşılaştır. Tabloda "Plane'de var mı?"
   kolonunu doldur (yoksa "YOK", varsa `PROJ-N`). Eşleşen bulgu için yeni issue açma —
   gerekiyorsa mevcut issue'ya yorum/güncelleme öner.

---

## Adım 6 — Katman katman onay (multiSelect)

Her katman için **bir** `AskUserQuestion` (`multiSelect: true`): "Hangileri için issue açayım?"
Seçenekler = o katmandaki bulgular (label kısa, description'da kanıt+öncelik). Kullanıcı
"hepsini aç" derse soruları atla.

> ask-first kuralı: onay/seçim **her zaman** AskUserQuestion ile; düz metin soru yasak.

---

## Adım 7 — Onaylananları sırayla aç (Claude)

1. Plane state UUID'sini çöz (genelde "Başlanmadı"/unstarted): `plane-cli state list --project <UUID>`.
2. **`log-triage` label UUID'si** (Adım 5'te bulunan/oluşturulan) hazır olsun.
3. Her onaylı bulgu için HTML açıklamayı **`references/issue_template.md`'deki zorunlu yapıya
   göre** üret: Sorun · Kapsam · **Kanıt (≥1 ham log örneği, PII maskeli)** · Sayım/Sıklık ·
   trace_id · Kök Neden · Öneri · **Tespit Bağlamı** (provenance). **Eksik bağlamlı issue yasak**
   — her bölüm dolu, veri yoksa "tespit edilemedi" yaz. İçeriği **`html.escape` ile** escape edip
   **dosyaya yaz** (özel karakter `<`, `"`, `()` inline geçince plane-cli/HTML parser bozulur —
   **dosyadan create zorunlu**).
   > **Log örneği zorunlu**: her issue en az 1 ham log satırı taşır (sonraki oturum sıfırdan
   > kazmadan doğrulayabilsin). PII'yı maskele — issue'nun kendisi sızıntı olmasın.
4. `scripts/create_issue.sh` ile sırayla aç (label UUID 6. argüman — **her issue `log-triage`
   label'ı alır**):
   ```bash
   "$HOME/.../log-triage/scripts/create_issue.sh" \
     "<proj_uuid>" "<state_uuid>" "<priority>" "<html_dosyası>" "<başlık>" "<label_uuid>"
   ```
5. Açılan `PROJ-N`'leri kullanıcıya katman tablosu olarak özetle.

> Priority eşlemesi: Katman1→`urgent`/`high`, Katman2→`high`/`medium`, Katman3→`medium`,
> Katman4→`medium`/`low` (güvenlik içerenler `high`).

---

## Görev Takibi

3+ pencere + workflow + issue açma çok adımlı → başta `TaskCreate` ile görev listesi aç
(çek / workflow / dedup+doğrula / tablo+onay / issue create), ilerledikçe `TaskUpdate`.

## İlgili

- `diji-logs` skill — VictoriaLogs/LogsQL sorgu katmanı (bu skill onun üstüne kurulu).
- `plane-cli` skill — issue CRUD.
- `references/workflow_template.md` — analiz Workflow script şablonu.
- `references/angles.md` — açı promptları (detaylı).
- `references/issue_template.md` — issue zorunlu bağlam yapısı (log örneği + provenance).
