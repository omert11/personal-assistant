# LogsQL Referansı (diji-logs için)

VictoriaLogs sorgu dili. Kaynak: https://docs.victoriametrics.com/victorialogs/logsql/

> **Bu skill bağlamında kritik fark:** Sunucu stream-selector'ı (`{env=...,project=...}`) **kendisi**
> üretir. Sen yalnız **`|` sonrası pipe stage**'leri verirsin. Yani aşağıdaki "Filtre" bölümü senin
> için **`filter`/`where` pipe'ının İÇİNDE** kullanılır:
> - ❌ `level:error` (çıplak filtre — sunucu selector'ından sonra gelemez, 400)
> - ✅ `filter level:error`  /  ✅ `where level:error and _msg:timeout`

---

## 1. Filtreler (`filter`/`where` pipe içinde kullan)

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
`-filter`, `!filter`, `NOT filter` → negasyon. Parantezle grupla.

### Zaman filtresi (pipe içinde de kullanılabilir ama genelde start/end param ile ver)
| Sözdizimi | Anlam |
|---|---|
| `_time:5m` | son 5 dakika |
| `_time:>1h` | 1 saatten eski |
| `_time:[2026-06-01Z,2026-06-25Z]` | aralık |
| `_time:day_range[08:00,18:00)` | günün saatleri |

---

## 2. Pipe'lar (izinli olanlar)

> Birden çok pipe `|` ile zincirlenir. **İlk stage** sunucu selector'ından sonra gelir.

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

### İstatistik (özet/agregasyon)
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

---

## 3. Özel alanlar

| Alan | Anlam |
|---|---|
| `_time` | timestamp (ns hassasiyet) |
| `_msg` | log mesaj gövdesi |
| `_stream` | stream etiketleri (JSON benzeri) |
| `_stream_id` | stream kimliği |

> `_stream` / `_stream_id`'yi **filtre/seçim için kullanma** — sunucu zaten stream'i scope'a göre
> sabitledi; bunlarla oynamak scope-escape sayılır ve serializer reddedebilir. Okuma/özet için
> görmen normal.

---

## 4. Zaman sözdizimi (start/end/step parametreleri)

**Relatif süre:** `5m`, `15m`, `1h`, `2h`, `24h`, `7d`, `1w`, `1y`, `1y2d3h4m5s`
**Mutlak (RFC3339):** `2026-06-25Z`, `2026-06-25T22:00Z`, `2026-06-25T22:45:59Z`, `2026-06-25+03:00`
**Unix timestamp:** saniye cinsinden tam sayı.

- `query/` → `start`/`end` opsiyonel; verilmezse VL varsayılan penceresi.
- `count/` → `step` **zorunlu** (bucket boyu): `1h` saatlik, `5m` 5 dakikalık, `1d` günlük.
  `start`/`end` ile pencere daralt.

---

## 5. Yasak (sunucu allowlist'i reddeder — 400)

- Ham stream-selector: `{env="x"}` veya herhangi `{` / `}`
- Backtick (`` ` ``)
- LogsQL yorumu: `/* ... */`
- Pipe'lar: `union`, `join`, `stream_context`, `replay` (başka stream'leri okur → scope dışı)
- Çıplak filtre (pipe komutu olmadan): `level:error` → `filter level:error` yap

---

## 6. Sık kullanılan reçeteler

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
