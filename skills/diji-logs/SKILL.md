---
name: diji-logs
description: Scope'un VictoriaLogs HTTP API'si üzerinden kapsamlı log arama/analiz; LogsQL üretip sorgular.
when_to_use: Trigger — "<proje> loglarına bak", "son N dk/saat hata var mı", "şu hatayı VL'de ara", "log sorgula", "logsql", "hata sayısını zamanla göster", "/diji-logs". Scope (dijiscope) tarzı bir VictoriaLogs erişim API'si olan projelerde (CLAUDE.local.md'de log API tanımlı veya scope.diji.app) log arama/teşhis gerektiğinde. Basket lifecycle/AppLog DB analizi DEĞİL — bu yalnız VL/LogsQL üzerinden.
argument-hint: [proje] [arama-ifadesi]
arguments: project query
allowed-tools: Bash, Read, AskUserQuestion
---

# Diji Logs — VictoriaLogs / LogsQL Arama

Scope (dijiscope) tipi bir **scoped VictoriaLogs erişim API'si** üzerinden log arar, sayar ve
teşhis eder. Kullanıcı bir proje seçer; skill LogsQL pipe'ı kurup `/api/logs/query/` ya da
`/api/logs/count/` çağırır, sonucu özetler.

> **Mimari sözleşme (neden böyle):** Kullanıcı **asla** ham stream-selector (`{...}`) veremez.
> Sunucu `(env, project)` seçimini kullanıcının scope'una göre doğrular ve selector'ı kendisi üretir;
> sen yalnız `project`, `env` ve **`|` sonrası narrowing pipe** (`filter`/`stats`/`sort`/`limit`…)
> gönderebilirsin. Bu skill o sözleşmeye uyar — selector enjekte etmeye çalışma, 400/403 alırsın.

> **Marka/proje adı uydurma:** Hangi projeler erişilebilir olduğunu **her zaman** `projects/`
> endpoint'inden öğren — hardcode etme. Domain bilgisi API'den gelir.

## Adım 0 — Ortamı çöz (base URL + token)

API kökü ve auth token gerekir. **`scripts/query.sh` bunları otomatik çözer** — credential'lar
kalıcı bir env dosyasında tutulur, bu yüzden **token'ı tekrar tekrar SORMA**.

### Credential kaynağı: `~/.config/diji-logs/env` (repo dışı, chmod 600)

Token + base URL şu dosyada saklanır ve `query.sh` her çağrıda **otomatik source eder**:

```bash
# ~/.config/diji-logs/env  (asla commit edilmez)
DL_BASE="https://scope.diji.app"
DL_TOKEN="<kullanıcının-token'ı>"
```

**Akış (sırayla):**

1. **Dosya varsa → hiçbir şey sorma.** Doğrudan Adım 1'e geç; `query.sh` token'ı kendi okur.
   Var mı kontrolü: `test -f ~/.config/diji-logs/env`.
2. **Dosya yoksa** kullanıcıdan token iste (scope arayüzü → `/logs/api/` → "Token'ımı Göster"),
   sonra dosyayı **bir kez** oluştur ki bir daha sorulmasın:
   ```bash
   mkdir -p ~/.config/diji-logs
   printf 'DL_BASE="%s"\nDL_TOKEN="%s"\n' "https://scope.diji.app" "<token>" \
     > ~/.config/diji-logs/env
   chmod 600 ~/.config/diji-logs/env
   ```
3. **Base URL**: Varsayılan prod (`https://scope.diji.app`). Lokal dev (`http://localhost:8231`)
   gerekiyorsa kullanıcı söyler; env dosyasındaki `DL_BASE`'i ona göre düzenle. Belirsizse
   `AskUserQuestion` ile teyit et (Prod / Lokal).
4. **Tek seferlik override**: `DL_TOKEN=... DL_BASE=... query.sh ...` şeklinde env geçilirse
   dosyadaki değeri ezer (test/başka kullanıcı için). Normal akışta gerek yok.

> Token'ı **asla** repo'ya, loga, transcript'e veya commit'e yazma. Sadece `~/.config/diji-logs/env`
> (600) içinde durur; `query.sh` `$DL_TOKEN` env'ine yükler. Manuel curl gerekiyorsa
> `source ~/.config/diji-logs/env` ile ortama al, token'ı komut satırına gömme.

> Token yetkisi **scope'ludur**: kullanıcı yalnız `LogAccess` include/exclude'una giren
> `(env, project)` çiftlerini görür. Scope dışı proje istenirse API **403** döner — bu beklenen
> davranış, retry etme; kullanıcıya "bu proje senin log kapsamında değil" de.

## Adım 1 — Erişilebilir projeleri listele (ZORUNLU ilk adım)

Proje seçmeden sorgu yapılamaz. Önce kapsamı çek:

```bash
curl -fsS -H "$AUTH" "$DL_BASE/api/logs/projects/"
# → {"projects":[{"env":"prod","project":"www.voyante.com"},{"env":"dev","project":"zenrota.diji.app"},...]}
```

- Kullanıcı projeyi `$project` argümanı veya isimle verdiyse listeden **eşleştir** (kısmi eşleşmede
  `AskUserQuestion` ile doğru olanı seçtir). Liste boşsa: token yanlış/yetki yok ya da VL erişilemiyor
  (`502`) — kullanıcıya bildir.
- `env` çoğu projede `prod`; aynı projenin hem `prod` hem `dev` kaydı olabilir — hangisi belirsizse sor.

## Adım 2 — Modu belirle ve LogsQL kur

| Kullanıcı ne der | Endpoint | Ne gönderilir |
|---|---|---|
| "son N log", "şu projenin logları" | `query/` | sadece `project`+`env`+`limit` |
| "şu hatayı/metni ara", "level error" | `query/` | `logsql` pipe ile `filter` |
| "kaç hata oldu", "zamanla dağılım", "saatlik sayı" | `count/` | `logsql` filter + `step` |
| "en sık X", "top error" | `query/` | `stats by (...) count()` + `sort` + `limit` |

LogsQL kurarken **`references/logsql.md`**'yi referans al — filtre/pipe sözdizimini ordan doğrula,
bellekten uydurma. Temel kurallar:

- Senin verdiğin `logsql` **her zaman `|` sonrası bir pipe stage**'dir (sunucu selector'ı önüne
  ekler). Bu yüzden çıplak filtre **geçmez**: `level:error` ❌ → `filter level:error` ✅ ya da
  `where level:error`.
- İzinli pipe'lar (narrowing/shaping): `filter`, `where`, `stats`, `sort`, `fields`, `limit`,
  `head`, `first`, `last`, `uniq`, `top`, `offset`, `extract`, `extract_regexp`, `format`, `math`,
  `rename`, `copy`, `delete`, `replace`, `replace_regexp`, `unpack_json`, `unpack_logfmt`,
  `unpack_syslog`, `facets`, `field_names`, `field_values`, `len`, `sample`, `decolorize`,
  `collapse_nums`, `drop_empty_fields`, `pack_json`, `pack_logfmt`, `unroll`.
- **Yasak** (scope dışına çıkar, 400 döner): ham `{...}` selector, backtick, `/* */` yorum,
  `union`, `join`, `stream_context`, `replay`.

## Adım 3 — Sorgula

`scripts/query.sh` üç alt-komutu sarmalar (curl + jq). Quoting derdini önler:

```bash
# Projeleri listele
"${CLAUDE_SKILL_DIR}/scripts/query.sh" projects

# Log çek: project env limit [logsql-pipe] [start] [end]
"${CLAUDE_SKILL_DIR}/scripts/query.sh" query "www.voyante.com" prod 100 "filter level:error" "5m"

# Zamanla say: project env step [logsql-pipe] [start] [end]
"${CLAUDE_SKILL_DIR}/scripts/query.sh" count "www.voyante.com" prod 1h "filter level:error" "24h"
```

Script `DL_BASE` ve `DL_TOKEN` env'lerini okur (Adım 0). Çıktı ham JSON → sen özetlersin.

> Çıktı **büyük** olabilir (yüksek limit/raw). `run_in_background: true` ile çalıştır, gerekirse
> `| jq '.logs | length'` ile önce say, sonra `head`'le ilk satırları incele — tamamını Read etme.
> JSON-lines `_time`, `_msg`, `_stream`, `level` gibi alanlar içerir; özetlerken `_time` + `_msg`
> + ilgili alanları kullan.

### Zaman aralığı (`start`/`end`)

VL hem relatif (`5m`, `1h`, `24h`, `7d`) hem RFC3339 (`2026-06-25T00:00:00Z`) hem unix timestamp
kabul eder. Kullanıcı "son 2 saat" derse `start=2h`. `count/` için `step` zorunlu (bucket boyu:
`1h`, `5m`, `1d`). Detay: `references/logsql.md` → "Zaman Sözdizimi".

## Adım 4 — Teşhis akışı (ref'siz "şu hata var mı")

Kullanıcı bir hata mesajı/ekran görüntüsü verip ref vermezse:

1. `projects/` ile kapsamı al, doğru projeyi seçtir.
2. Metnin ayırt edici parçasını **substring/phrase filter** ile ara:
   `query` + `filter "<mesaj parçası>"` (boşluklu ifade tırnak içinde) + `start` geniş (`24h`).
3. Sonuç 0 ise: env'i değiştir (prod↔dev), zaman aralığını genişlet, ya da kelimeyi gevşet
   (substring `*parça*`, case-insensitive `i(parça)`).
4. Eşleşen satırlardan `_stream`/`_time` çıkar; gerekirse o pencerede `count/` ile yoğunluğu göster.

## Hata kodları (API)

- **400** — `logsql` izinli değil (çıplak filtre, yasak pipe, ham selector) veya `project` eksik.
  Pipe'ı `filter`/`where` ile sarmala, tekrar dene.
- **403** — istenen `(env, project)` kullanıcının log kapsamı dışında. Retry etme; kapsamı `projects/`
  ile göster, kullanıcıya bildir.
- **502** — VictoriaLogs erişilemiyor (tünel/servis down). Kullanıcıya altyapı sorunu olarak bildir.
- **401** — token geçersiz/eksik veya süresi dolmuş. `~/.config/diji-logs/env` içindeki `DL_TOKEN`
  eskimiş olabilir: kullanıcıdan yeni token al, dosyayı güncelle (`chmod 600` koru), tekrar dene.

## Notlar

- API endpoint'leri ve scope mantığı dijiscope `scope/api/logs/` altında tanımlı (proxy + serializer +
  scope resolver). Skill bu sözleşmenin **istemci tarafı** — sunucu allowlist'ini taklit eder ki
  gereksiz 400 yememek için pipe'ı doğru kursun.
- Token kişiseldir ve scope'ludur; farklı kullanıcılar farklı proje setleri görür. Skill kimin
  token'ıysa onun kapsamında çalışır.
