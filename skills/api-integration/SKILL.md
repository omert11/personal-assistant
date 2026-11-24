---
name: api-integration
description: Harici API'yi platform yetenekleriyle eşler, akışı doğrular, dokümante eder ve entegre eder.
when_to_use: Trigger — "API entegre et", "yeni API entegrasyonu", "şu servisi bağla", "sağlayıcı entegrasyonu", "/api-integration <doküman|url>". Platforma yeni bir harici API/sağlayıcı bağlanacağında.
argument-hint: <api-dokümanı-url | dosya-yolu | sağlayıcı-adı>
allowed-tools: Skill, Agent, Read, Bash, Grep, Glob, WebFetch, AskUserQuestion
---

# API Integration

## Ön koşul

- API dokümanı kesin olmalı. `$ARGUMENTS` doküman vermiyorsa soru aracıyla iste (header: "Doküman", options: ["URL", "Dosya yolu", "Doküman yok"]).
- Doküman yoksa veya iletilemiyorsa dur; sonraki adıma geçme.
- Vault'ta `docs/<kaynak>/` zaten varsa `obsidian-search` ile oku ve başlangıç kaynağı olarak kullan.

## 1. Durum analizi

- Platformda daha önce entegre edilmiş API'leri incele: ortak katman, adapter/provider yapısı, hata ve log deseni, test yaklaşımı, kritik noktalar.
- Platformun mevcut yetenek ağacını çıkar (ör. arama, rezervasyon, ek hizmet, koltuk seçimi, iptal, iade).
- Dokümandaki API yetenek ağacını çıkar ve platform ağacıyla eşle:

| Durum | Aksiyon |
|---|---|
| Platformda var, API karşılıyor | Kapsama zorunlu ekle |
| Platformda var, API karşılamıyor | Rapora "karşılanmıyor" olarak yaz |
| API'de var, platformda yok | Soru aracıyla kapsama alınıp alınmayacağını sor (multiSelect, tek blok) |

- Yetenek kapsamı kesinleşmeden 2. adıma geçme.

## 2. Kaynak hazırlığı ve akış doğrulama

- Test credential'ı ara: kullanıcının ilettiği, credential skill'leri, dokümanın kendisi (bazı sağlayıcılar ortak test credential'ı paylaşır).
- Test erişimi varsa kapsamdaki her yetenek akışını curl ile uçtan uca dene: başarılı senaryo, hata senaryoları, sınır durumları. Gerçek kaynak API cevabıdır; dokümanla çelişen her davranışı not et.
- Test erişimi yoksa akışları ve kritik noktaları dokümandan yetenek yetenek çıkar; doğrulanmadığını not et.
- Her akış için çıkar: istek sırası, zorunlu alanlar, durum/oturum taşıma (token, session, offer id), zaman aşımı, idempotency, hata kodları, limitler.

## 3. Dokümantasyon

- `obsidian-doc-source` skill'ini çağır; kaynak API dokümanıdır.
- Doküman bölümlerine 2. adım bulgularını ekle: doğrulanan akışlar (istek/yanıt örneği), dokümanla çelişen gerçek davranışlar, yetenek eşleme tablosu.
- `index.md` "Kaynak ve Edinim" bölümünde doğrulama durumunu akış başına ✅/❌ + tarih ile yaz.
- Credential değerlerini dokümana yazma; yalnız bulunduğu skill/notu referansla.

## 4. Geliştirme

- `orchestrate` skill'ini çağır; kaynak olarak vault doküman yolunu ve 1. adımdaki kesin yetenek kapsamını ver.
