---
name: diji-logs
description: Scope'un VictoriaLogs HTTP API'si üzerinden kapsamlı log arama/analiz; LogsQL üretip sorgular.
when_to_use: Trigger — "<proje> loglarına bak", "son N dk/saat hata var mı", "şu hatayı VL'de ara", "log sorgula", "logsql", "hata sayısını zamanla göster", "/diji-logs". Scope (dijiscope) tarzı bir VictoriaLogs erişim API'si olan projelerde (AGENTS.md'de log API tanımlı veya scope.diji.app) log arama/teşhis gerektiğinde. Basket lifecycle/AppLog DB analizi DEĞİL — bu yalnız VL/LogsQL üzerinden.
argument-hint: [proje] [arama-ifadesi]
arguments: project query
allowed-tools: Bash, Read, AskUserQuestion
---

# Diji Logs — VictoriaLogs / LogsQL Arama

- Ham stream-selector (`{...}`) gönderme; sunucu `(env, project)`'i scope'a göre doğrulayıp selector'ı kendisi üretir. Yalnız `project`, `env` ve `|` sonrası narrowing pipe gönder (aksi 400/403).
- Erişilebilir projeleri her zaman `projects/` endpoint'inden öğren; proje adı hardcode etme/uydurma.

## Adım 0 — Credential (base URL + token)

`scripts/query.sh` her çağrıda `~/.config/diji-logs/env` (repo dışı, chmod 600) dosyasını source eder:

```bash
DL_BASE="https://scope.diji.app"
DL_TOKEN="<kullanıcının-token'ı>"
```

1. Dosya varsa (`test -f ~/.config/diji-logs/env`) hiçbir şey sorma, Adım 1'e geç.
2. Yoksa token iste (scope arayüzü → `/logs/api/` → "Token'ımı Göster"), dosyayı bir kez oluştur:
   ```bash
   mkdir -p ~/.config/diji-logs
   printf 'DL_BASE="%s"\nDL_TOKEN="%s"\n' "https://scope.diji.app" "<token>" \
     > ~/.config/diji-logs/env
   chmod 600 ~/.config/diji-logs/env
   ```
3. Base URL varsayılan prod `https://scope.diji.app`; kullanıcı lokal derse `http://localhost:8231` yap (`DL_BASE`'i düzenle). Belirsizse soru aracıyla sor (Prod / Lokal).
4. Tek seferlik override: `DL_TOKEN=... DL_BASE=... query.sh ...` dosyayı ezer.

- Token'ı repo'ya, loga, transcript'e, commit'e veya komut satırına yazma. Manuel istek için `source ~/.config/diji-logs/env`.
- Token scope'ludur (`LogAccess` include/exclude). Scope dışı proje → 403: retry etme, "bu proje senin log kapsamında değil" de.

## Adım 1 — Projeleri listele (ZORUNLU ilk adım)

```bash
curl -fsS -H "$AUTH" "$DL_BASE/api/logs/projects/"
# → {"projects":[{"env":"prod","project":"www.voyante.com"},{"env":"dev","project":"zenrota.diji.app"},...]}
```

- `$project`/isimle verilen projeyi listeden eşleştir; kısmi eşleşmede soru aracıyla seçtir.
- Liste boşsa: token yanlış/yetki yok ya da VL erişilemiyor (502) — bildir.
- `env` çoğunlukla `prod`; aynı proje hem `prod` hem `dev` olabilir — belirsizse sor.

## Adım 2 — Mod ve LogsQL

| Kullanıcı ne der | Endpoint | Ne gönderilir |
|---|---|---|
| "son N log", "şu projenin logları" | `query/` | sadece `project`+`env`+`limit` |
| "şu hatayı/metni ara", "level error" | `query/` | `logsql` pipe ile `filter` |
| "kaç hata oldu", "zamanla dağılım", "saatlik sayı" | `count/` | `logsql` filter + `step` |
| "en sık X", "top error" | `query/` | `stats by (...) count()` + `sort` + `limit` |

Sözdizimini `references/logsql.md`'den doğrula, bellekten uydurma.

- `logsql` her zaman `|` sonrası pipe stage'dir; çıplak filtre geçmez: `level:error` ❌ → `filter level:error` / `where level:error` ✅.
- İzinli pipe'lar: `filter`, `where`, `stats`, `sort`, `fields`, `limit`, `head`, `first`, `last`, `uniq`, `top`, `offset`, `extract`, `extract_regexp`, `format`, `math`, `rename`, `copy`, `delete`, `replace`, `replace_regexp`, `unpack_json`, `unpack_logfmt`, `unpack_syslog`, `facets`, `field_names`, `field_values`, `len`, `sample`, `decolorize`, `collapse_nums`, `drop_empty_fields`, `pack_json`, `pack_logfmt`, `unroll`.
- Yasak (400): ham `{...}` selector, backtick, `/* */` yorum, `union`, `join`, `stream_context`, `replay`.

## Adım 3 — Sorgula

```bash
# Projeleri listele
"${CLAUDE_SKILL_DIR}/scripts/query.sh" projects

# Log çek: project env limit [logsql-pipe] [start] [end]
"${CLAUDE_SKILL_DIR}/scripts/query.sh" query "www.voyante.com" prod 100 "filter level:error" "5m"

# Zamanla say: project env step [logsql-pipe] [start] [end]
"${CLAUDE_SKILL_DIR}/scripts/query.sh" count "www.voyante.com" prod 1h "filter level:error" "24h"
```

- Çıktı ham JSON; özetle (`_time` + `_msg` + ilgili alanlar; `_stream`, `level` de gelir).
- Büyük çıktıda `run_in_background: true`; önce log sayısını (`.logs | length`) say, sonra ilk kayıtları incele; tamamını okuma.
- `start`/`end`: relatif (`5m`, `1h`, `24h`, `7d`), RFC3339 (`2026-06-25T00:00:00Z`) veya unix timestamp. "son 2 saat" → `start=2h`.
- `count/` için `step` zorunlu (`1h`, `5m`, `1d`). Detay: `references/logsql.md` → "Zaman sözdizimi".

## Adım 4 — Teşhis (ref'siz "şu hata var mı")

1. `projects/` ile kapsamı al, projeyi seçtir.
2. Mesajın ayırt edici parçasını ara: `query` + `filter "<mesaj parçası>"` (boşluklu ifade tırnakta) + `start=24h`.
3. Sonuç 0 ise: env değiştir (prod↔dev), zaman aralığını genişlet veya gevşet (`*parça*`, `i(parça)`).
4. Eşleşen satırlardan `_stream`/`_time` çıkar; gerekirse o pencerede `count/` ile yoğunluğu göster.

## Hata kodları

- **400** — izinsiz `logsql` (çıplak filtre, yasak pipe, ham selector) veya `project` eksik. `filter`/`where` ile sarmala, tekrar dene.
- **401** — token geçersiz/eksik/süresi dolmuş. Yeni token al, `~/.config/diji-logs/env`'i güncelle (`chmod 600` koru), tekrar dene.
- **403** — `(env, project)` kapsam dışı. Retry etme; `projects/` ile kapsamı göster, bildir.
- **502** — VictoriaLogs erişilemiyor (tünel/servis down). Altyapı sorunu olarak bildir.
