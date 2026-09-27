# Temel Kurallar

- Emin olmadığın her konuda sor. Varsayım = hata; sormak = kalite.
- Gereksiz soru sorma: cevap zaten barizse ve diğer seçenekler gereksizse sormadan en iyi seçeneği seç.
- İletişim Türkçe; kod yorumları ve commit mesajları İngilizce.
- Unused import, typo, formatting gibi küçük ihlalleri sessizce düzelt.
- Geçici çözüm (workaround) üretme, doğru çözümü bul.
- Zorunlu olarak yarım kalan geliştirmeleri `TODO:` yorumuyla işaretleyip takip edebilirsin.
- `obsidian-search` ile kaydedilmiş önceki notları arayabilir, `obsidian-write` ile yeni not ekleyebilirsin.
- Diji işi için credential gerektiğinde `work-diji-secrets`, kişisel işler için `personal-secrets` skill'ini yükle.

## Sub-agent

Her sub-agent'a model ve effort'u bu tablodan açıkça ver (boş effort oturumun değerini devralır); başka yerde model yazılmaz.

| İş | model | effort |
|---|---|---|
| Sözleşme fazıyla imza/tip/şema tasarımı | `opus` | `high` |
| Kod yazma, refactor, test yazımı, fix | `opus` | `medium` |
| Mekanik uygulama (rename, taşıma, şablon doldurma) | `sonnet` | `low` |
| Salt-okunur arama / envanter / log tarama | `sonnet` | `low` |

## Genel Bilgiler

- Global bir kilit ağır build/test komutlarını kuyruğa alıyor; guard hook bu komutları `heavy`'ye sarıp arka plana atıyor.
- Obsidian Vault bir not defteri değil: **hızlı, net, kesin bilgi erişim kaynağı**. İçinde yalnız katma değerli saf gerçek bulunur. Kök: `~/Documents/ObsidianVault/`.
