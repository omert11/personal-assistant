# Temel Kurallar

- Emin olmadığın her konuda sor. Varsayım = hata; sormak = kalite.
- Gereksiz soru sorma: cevap zaten barizse ve diğer seçenekler gereksizse sormadan en iyi seçeneği seç.
- İletişim Türkçe; kod yorumları ve commit mesajları İngilizce.
- Unused import, typo, formatting gibi küçük ihlalleri sessizce düzelt.
- Geçici çözüm (workaround) üretme, doğru çözümü bul.
- Zorunlu olarak yarım kalan geliştirmeleri `TODO:` yorumuyla işaretleyip takip edebilirsin.
- `obsidian-search` ile kaydedilmiş önceki notları arayabilir, `obsidian-write` ile yeni not ekleyebilirsin.
- Diji işi için credential gerektiğinde `work-diji-secrets`, kişisel işler için `personal-secrets` skill'ini yükle.
- Diji deploy, release, rollback, Dokploy, yeni site/domain, canlı env/migration veya altyapı işinde `work-diji-deploy` skill'ini yükle.
- `dijii-tech` repolarında PR başlığı conventional commit olmalı (`feat:`, `fix:`, `chore:`…; kırıcı değişiklikte `type!:`); release-bot sürümü başlıktan üretir.
- Remote çalışma ortamı (diji sunucusundaki `work` container'ı: bağlantı, port, DB, dosya aktarımı, limit) hakkında bilgi gerektiğinde `remote-workspace` skill'ini yükle.
- Tarayıcı disiplini: açtığın sekmeyi iş bitince kapat; tek tarayıcı örneğini paylaş, test başına yeni tarayıcı açma; tarayıcı testlerini en fazla 2 paralel worker ile çalıştır.
- Remote ortamda kullanıcı oturumu açık bir tarayıcı gerektiğinde `gbrowser` skill'ini yükle.

## Sub-agent

Model ve effort'u tablodan açıkça ver; çağrı model almıyorsa o modele atanmış agent'ı kullan. Başka yerde model yazılmaz.

| İş | model | effort |
|---|---|---|
| Orchestrator & İleri Teknik Kod Yazma | `opus 5.5` | `medium` |
| Diğer Herşey | `sonnet 5.5` | `medium` |

## Genel Bilgiler

- Global bir kilit ağır build/test komutlarını kuyruğa alıyor; guard hook bu komutları `heavy`'ye sarıp arka plana atıyor.
- Obsidian Vault bir not defteri değil: **hızlı, net, kesin bilgi erişim kaynağı**. İçinde yalnız katma değerli saf gerçek bulunur. Kök: `~/Documents/ObsidianVault/`.
