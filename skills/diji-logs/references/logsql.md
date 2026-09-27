# LogsQL Referansı (diji-logs için)

Kaynak: https://docs.victoriametrics.com/victorialogs/logsql/

Stream-selector'ı sunucu üretir; sen yalnız `|` sonrası pipe stage verirsin. Filtreleri `filter`/`where` pipe içinde kullan:
- ❌ `level:error` (çıplak filtre, 400)
- ✅ `filter level:error` / ✅ `where level:error and _msg:timeout`

## 1. Filtreler (`filter`/`where` içinde)

### Tam metin
| Sözdizimi | Anlam |
|---|---|
| `error` | `_msg`'de "error" kelimesi |
| `field:word` | `field` alanında kelime |
| `"exact phrase"` | birebir ifade (boşluklu) |
| `field:"phrase"` | alanda ifade |
| `err*` | "err" ile başlayan (prefix) |
| `*substr*` | herhangi yerde substring |
| `i(error)` | case-insensitive kelime |
| `i("err msg")` | case-insensitive ifade |

### Tam değer / çoklu değer
| Sözdizimi | Anlam |
|---|---|
| `field:="exact value"` | alan birebir bu değere eşit |
| `field:="err"*` | alan "err" ile başlar (exact-prefix) |
| `field:in("error","fatal")` | alan listedeki değerlerden biri |
| `field:""` | alan boş/yok |
| `field:*` | alan dolu (boş değil) |

### Karşılaştırma / aralık
| Sözdizimi | Anlam |
|---|---|
| `status:>=500` | sayısal ≥ |
| `size:>10KiB` | KiB/MiB destekli |
| `n:range[10,100]` | kapalı aralık |
| `n:range(10,100)` | açık aralık |
| `msg:len_range[10,100]` | değer uzunluğu aralığı |
| `ip:ipv4_range(10.0.0.0,10.255.255.255)` | IPv4 aralığı |

### Regexp / negatif
| Sözdizimi | Anlam |
|---|---|
| `~"pat"` | `_msg` regexp eşleşmesi |
| `field:~"pat"` | alan regexp |
| `~"(?i)pat"` | case-insensitive regexp |
| `!~"pat"` | negatif regexp |
| `field:!=value` | alan bu değere eşit DEĞİL |

### İçerik
| Sözdizimi | Anlam |
|---|---|
| `contains_all(foo,"bar baz")` | hepsi geçer (= AND) |
| `contains_any(foo,bar)` | en az biri (= OR) |
| `seq(a,b,c)` | sırayla geçer |

### Mantıksal (öncelik: NOT > AND > OR)
```
filter error AND status:>=500
filter (timeout OR refused) AND -healthcheck
where level:error and not _msg:"debug"
```
Negasyon: `-filter`, `!filter`, `NOT filter`. Parantezle grupla.

### Zaman filtresi (tercihen `start`/`end` param kullan)
| Sözdizimi | Anlam |
|---|---|
| `_time:5m` | son 5 dakika |
| `_time:>1h` | 1 saatten eski |
| `_time:[2026-06-01Z,2026-06-25Z]` | aralık |
| `_time:day_range[08:00,18:00)` | günün saatleri |

## 2. Pipe'lar (izinli)

Pipe'lar `|` ile zincirlenir; ilk stage sunucu selector'ından sonra gelir.

### Filtreleme / şekillendirme
```
| filter level:error                  # ek filtre
| where status:>=500 and _msg:timeout # filter ile eşdeğer
| fields _time, _msg, level           # sadece bu alanları döndür
| sort by (_time) desc                # sırala
| limit 50                            # ilk N (alias: head, first)
| last 10                             # son N
| offset 20 | limit 10                # sayfalama
| uniq by (_stream)                   # tekilleştir
| top 10 by (level)                   # frekansa göre ilk N
| sample 0.1                          # %10 örnekle
```

### İstatistik
```
| stats count() as total
| stats by (level) count() as cnt
| stats by (_time:5m) count() as per5m       # zaman bucket'ı
| stats by (status) count() as c, avg(duration) as avg_dur
```
Fonksiyonlar: `count()`, `count_uniq(f)`, `sum(f)`, `avg(f)`, `min(f)`, `max(f)`,
`median(f)`, `quantile(0.95, f)`, `uniq_values(f)`, `values(f)`, `first(f)`, `last(f)`.

### Metin işleme
```
| extract "user_id=<uid> status=<st>"        # pattern ile alan çıkar
| extract_regexp "(?P<code>[A-Z]+\d+)"       # regex grup ile
| format ("{level}: {_msg}") as line
| replace (_msg, "secret", "***") as _msg
| unpack_json from data                       # JSON alanı aç
| math (duration / 1000) as dur_sec
| collapse_nums as pattern                    # sayıları <N> ile değiştir (gruplama)
| len (_msg) as msg_len
```

### Alan yönetimi
```
| rename old as new
| copy src as dst
| delete tmp1, tmp2
| drop_empty_fields
| field_values level                          # bir alanın benzersiz değerleri
| field_names                                 # tüm alan adları
```

## 3. Özel alanlar

| Alan | Anlam |
|---|---|
| `_time` | timestamp (ns hassasiyet) |
| `_msg` | log mesaj gövdesi |
| `_stream` | stream etiketleri (JSON benzeri) |
| `_stream_id` | stream kimliği |

`_stream` / `_stream_id`'yi filtre/seçimde kullanma (scope-escape, serializer reddedebilir); yalnız okuma/özet için.

## 4. Zaman sözdizimi (start/end/step)

- Relatif: `5m`, `15m`, `1h`, `2h`, `24h`, `7d`, `1w`, `1y`, `1y2d3h4m5s`
- Mutlak (RFC3339): `2026-06-25Z`, `2026-06-25T22:00Z`, `2026-06-25T22:45:59Z`, `2026-06-25+03:00`
- Unix timestamp: saniye, tam sayı.
- `query/`: `start`/`end` opsiyonel; verilmezse VL varsayılan penceresi.
- `count/`: `step` zorunlu (`1h` saatlik, `5m` 5 dakikalık, `1d` günlük); pencereyi `start`/`end` ile daralt.

## 5. Yasak (400)

- Ham stream-selector: `{env="x"}` veya herhangi `{` / `}`
- Backtick (`` ` ``)
- LogsQL yorumu: `/* ... */`
- Pipe'lar: `union`, `join`, `stream_context`, `replay`
- Çıplak filtre: `level:error` → `filter level:error`

## 6. Reçeteler

```
# Son 100 hata
query  project=... env=prod limit=100  logsql="filter level:error"  start=24h

# "timeout" geçen logları zamanla say (saatlik)
count  project=... env=prod step=1h    logsql="filter _msg:timeout"  start=24h

# Level'a göre dağılım
query  project=... env=prod limit=50   logsql="stats by (level) count() as c | sort by (c) desc"

# Belirli bir hata mesajını ara (substring, geniş pencere)
query  project=... env=prod limit=200  logsql='filter "Connection refused"'  start=7d

# 500'leri endpoint'e göre topla
query  project=... env=prod limit=20   logsql="filter status:>=500 | stats by (path) count() as c | sort by (c) desc | limit 20"
```
