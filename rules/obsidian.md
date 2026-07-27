# Obsidian — Super Brain

Vault bir not defteri değil. **Hızlı, net, kesin bilgi erişim kaynağı.** İçinde yalnız katma değerli saf gerçek bulunur.

Kök: `~/Documents/ObsidianVault/`

## Ne DEĞİLDİR

- Not alma aracı değil — "şunu da yazayım" diye dosya açılmaz
- Karalama defteri / geçmiş kaydı değil — kronoloji tutulmaz
- Proje yapısı belgesi değil — stack, dizin ağacı, README özeti, commit aktivitesi YAZILMAZ
- Oturum özeti deposu değil

## Ne YAZILIR

Yalnız iki tip:

1. **Bilgi** — sistem/araç/servis gerçekte nasıl çalışıyor; erişim bilgisi (credential/sunucu/endpoint) dahil
2. **Karar** — ne yapılacağına dair verilmiş kalıcı hüküm

Bug'ın kendisi yazılmaz, **nihai öğretiye dönüştürülür**: "Akbank hash açığı vardı, kapatıldı" değil → "Ödemenin kullanıcı tarafından geldiği `HashParamsVal` ile doğrulanmalı".

Dosya bir konunun **şu anki gerçeğini** taşır: tarih başlığı, changelog, kanıt (ticket/PNR/commit), hikâye ve yorum yazılmaz. Bilgi değişince mevcut satır düzeltilir, alta bölüm eklenmez.

Şüphedeysen **YAZMA**. Vault şişkinliği erişimi yavaşlatır — asıl maliyet budur.

## Klasör Mimarisi

```
~/Documents/ObsidianVault/
├── docs/                    # Dış kaynak dokümantasyonu (obsidian-doc-source üretir)
├── <proje>/                 # Proje-spesifik: <proje>/<modül>/<konu>.md
└── <alan>/                  # Genel bilgi — tüm projeleri besler
    ├── django/  rust/  flight/  hotel/  tour/  payment/
    └── frontend/  mobile/  diji-tech/  personal/
```

**Derinlik sınırı 3 seviye.** `b2b-dmc/flight/search/brand.md` geçerli; dördüncü seviye yasak — daha derine inmek gerekiyorsa konu yanlış bölünmüştür.

**Proje mi genel mi?** Ölçüt: *"Bu bilgiyi başka bir repoda çalışırken de arar mıyım?"* → Evet ise genel alan. THY'nin brand davranışı `flight/`e ait; projenin kendi checkout pipeline'ı projeye.

**`index.md` YOK.** Proje ve alan klasörlerinde MOC kullanılmaz — klasör yapısı zaten haritadır; ayrı bir yönlendirme dosyası hem bayatlar hem şişer.

Tek istisna `docs/`: dış kaynak dokümantasyonu bölümlere ayrılmış çok dosyalı yapıdır, `docs/index.md` (kaynak listesi) ve `docs/<source>/index.md` (bölüm listesi) `obsidian-doc-source` tarafından üretilir.

## Erişim — Subagent YOK

Vault'a **okuma ve yazma ana agent tarafından yapılır.** Subagent'a devretme.

Sebep: devirde bilgi prompt'a serialize edilir, teknik kesinlik (parametre adı, limit değeri, hata metni) yolda kaybolur ve devralan taraf kaybı fark edemez.

| İş | Skill |
|---|---|
| Arama | `obsidian-search` |
| Yazma | `obsidian-write` |
| Dış kaynak dokümantasyonu | `obsidian-doc-source` |

Skill'ler akışın tamamını (arama stratejisi, self-check, dosya formatı, frontmatter) tanımlar — burada tekrarlanmaz.

## Ne Zaman Obsidian, Ne Zaman Memory

- **Obsidian** → Teknik gerçek: sistem davranışı, credential, kalıcı karar (proje-spesifik veya alan geneli)
- **`~/.claude/memory/`** → Kullanıcı profili, çalışma tercihi, cross-project referans
- **`~/.claude/rules/`** → Tüm projelerde geçerli davranış kuralı (bu dosya gibi)
