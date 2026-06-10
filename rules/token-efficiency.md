# Token Efficiency

Subagent ve Workflow ajanlarında modeli her zaman bilinçli seç — varsayılana bırakma. Amaç: en küçük **yeterli** model.

## Agent Yazarken (frontmatter)

- Yeni agent tanımına **her zaman açık `model:`** yaz. Geçerli değerler: `haiku` / `sonnet` / `opus` / `fable`, tam model ID veya `inherit`.
- Görev tipi eşlemesi:
  - **haiku** → mekanik çıkarım/rapor: manifest okuma, dizin haritalama, git log analizi, BM25 arama + kısa sentez, scrape temizleme
  - **sonnet** → yapısal yazım, orchestration, çeviri/lokalizasyon, orta düzey muhakeme
  - **opus / inherit** → derin muhakeme, karmaşık kod analizi, güvenlik-kritik iş
- Sık tetiklenen agent'larda (hook tabanlı, her prompt'ta çalışan) küçük model seçimi en yüksek tasarrufu verir.

## Workflow Yazarken (`agent()` çağrıları)

- Workflow script'indeki ham `agent()` çağrıları plugin agent frontmatter'ını **kullanmaz** — `opts.model` belirtilmezse ana oturum modelini devralır.
- Paralel fan-out yapan her `agent()` çağrısına açık `model` yaz:

```js
agent(prompt, { label: 'translate:ar', phase: 'Translate', model: 'sonnet', schema })
```

- `subagent_type`/`agentType` ile named plugin agent çağrılıyorsa frontmatter modeli geçerlidir — ayrıca model geçirme.

## Maliyet Referansı

- haiku ≈ Opus'un ~1/25'i, sonnet ≈ ~1/5'i
- N dil/N dosya paralel fan-out'ta model farkı doğrusal çarpan: 13 dilde Opus yerine sonnet ≈ ~5x, haiku ≈ ~25x ucuz