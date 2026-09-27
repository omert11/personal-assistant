# AI Yazım İzleri — Kural İskeleti + Kaynak Okuma Alanları

Belgede yalnız desen ve süreç kuralları var. Kelime, ifade, oran, dönem, model bilgisi her koşuda BÖLÜM 0 URL'lerinden okunur.

---

# BÖLÜM 0 — KAYNAK OKUMA ALANLARI (ZORUNLU)

İşe başlamadan canlı oku. Okunmadan kural uygulanmaz.

## S1 — Wikipedia: Signs of AI writing (ana otorite)

```
https://en.wikipedia.org/w/index.php?title=Wikipedia:Signs_of_AI_writing&action=raw
```

Oku:
- Her bölümün `Words to watch` kutuları (tam liste)
- `High density of "AI vocabulary" words`: kelime → model dönemi kırılımı
- `Internal formatting and reference markup bugs`: araç bazlı imzalar (ChatGPT / Gemini / Grok / DeepSeek / Perplexity / sınıflandırılmamış)
- `utm_source=` parametre listesi
- `Differences between LLMs`
- `Ineffective indicators`, `Signs of human writing`
- `Caveats`: dedektör ve insan yargısı ölçümleri

- `Wikipedia:WikiProject AI Cleanup/AI catchphrases` bu sayfaya redirect; ayrıca okunmaz.
- Bölüm adı değişmişse kısayol kodlarıyla bul (`WP:AIVOCAB`, `WP:AIDASH` vb.).

## S2 — jooray/humanizer (numaralı desen kataloğu + süreç)

```
https://raw.githubusercontent.com/jooray/humanizer/main/SKILL.md
```

Oku:
- Numaralı desen bölümlerinin tamamı (`Words to watch` + before/after)
- `Voice Calibration`, `PERSONALITY AND SOUL`, `Invocation Modes`, `Detect Mode`, `Process and Output`
- `DETECTION GUIDANCE`: false-positive listesi, insan yazımı işaretleri
- Em dash bölümünün katılık seviyesi ve istisnası
- Frontmatter `metadata.version`

Mirror: `https://raw.githubusercontent.com/blader/humanizer/main/SKILL.md`. Sürümleri karşılaştır; büyük olanı oku, diğerini atla.

## S3 — jalaalrd/anti-ai-slop-writing (üretim direktifi + yasak listeler)

```
https://raw.githubusercontent.com/jalaalrd/anti-ai-slop-writing/main/skills/anti-ai-slop-writing/SKILL.md
https://raw.githubusercontent.com/jalaalrd/anti-ai-slop-writing/main/skills/anti-ai-slop-writing/references/banned-words.md
```

Oku:
- `Banned Vocabulary`, `Banned Phrases`, `Banned Sentence/Paragraph Openers` (tam liste)
- `Model-Specific First-Word Tells`
- `Era-Specific AI Vocabulary`
- `Structural Rules`, `Punctuation Rules`: sayısal eşikler (em dash, ünlem, ellipsis sıklığı; ardışık aynı uzunlukta cümle sınırı)
- `Self-Check Before Every Output`: güncel sıra ve sayı

## S4 — bharvey2026/humanise-skill (swap tabloları + editör akışı)

```
https://raw.githubusercontent.com/bharvey2026/humanise-skill/main/SKILL.md
```

Oku:
- Üç swap tablosu (AI Word / AI Adjective / AI Noun)
- `Sentence Structure Fixes`, `Tone Fixes`, `Opening & Closing Fixes`, `Transition Fixes` kalıp listeleri
- `Workflow` adımları, em dash oranı
- Frontmatter `model` / `effort`

## S5 — haidrrrry/humanize-ai-writing (tells kataloğu + checklist + prompt)

```
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/SKILL.md
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/references/ai-tells.md
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/references/rewrite-rules.md
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/assets/checklist.md
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/PROMPT.md
```

Oku:
- `ai-tells.md`: tell kataloğu, model-eğilimli kelime kümeleri, markup artifact listesi, "not reliable on their own" maddeleri, composite signal tanımı
- `rewrite-rules.md`: tell başına before/after kalıbı, swap çiftleri
- `checklist.md`: teslim öncesi liste (sürümle değişir)
- `PROMPT.md`: yapıştırılabilir sistem promptu; yasak kelime ve kalıp blokları

## S6 — Genişletme kaynakları (opsiyonel, konu gerektirirse)

```
https://en.wikipedia.org/w/index.php?title=Wikipedia:Signs_of_AI-generated_comments&action=raw
https://en.wikipedia.org/w/index.php?title=Wikipedia:WikiProject_AI_Cleanup/Guide_and_resources&action=raw
https://en.wikipedia.org/w/index.php?title=Wikipedia:Identifying_LLM_unblock_requests&action=raw
```

Sırasıyla: yorum/tartışma metni işaretleri, temizlik prosedürü, uzun savunma metni kalıpları.

## S7 — Okuma protokolü

1. **Tespit**: S1 + S5/`ai-tells.md` zorunlu; diğerleri opsiyonel.
2. **Yeniden yazma / temizleme**: S2 + S5/`rewrite-rules.md` + `checklist.md` zorunlu; S4 swap tabloları opsiyonel.
3. **Sıfırdan üretim**: S3 + S5/`PROMPT.md` zorunlu.
4. URL 404 → repo ağacını oku: `https://api.github.com/repos/<owner>/<repo>/git/trees/HEAD?recursive=1`.
5. Okuma başarısız → kurallar hatırlanarak uygulanmaz; eksik kaynak açıkça bildirilir.

Kaynaklar arası çelişki: BÖLÜM 6.

---

# BÖLÜM 1 — BURADA TUTULMAYAN

Bu belgeye kopyalanmaz; kopyalanmışsa silinir:

- Yasak kelime, ifade, cümle başlangıcı listeleri
- Kelime → karşılık swap tabloları
- Dönem bazlı kelime kırılımları
- Model imzaları: ilk kelime eğilimleri, markup artifact string'leri, UTM parametreleri
- Sayısal eşikler: em dash / ünlem / ellipsis oranları, ardışık cümle sınırları
- Çalışma sonuçları, yüzdeler, ölçümler, tarihler
- Skill sürüm numaraları, frontmatter değerleri
- Hangi modelin şu an neyi az/çok kullandığı

---

# BÖLÜM 2 — DESEN KURALLARI

Somut kelime/ifade ilgili kaynaktan okunur.

## 2.1 Anlam şişirme

- **Significance / legacy / broader-trend padding** — Konunun rastgele bir yönünü daha geniş bir olgunun temsili/katkısı gibi sunmak. Düzeltme: ne olduğunu ve ne yaptığını yaz, önem yorumunu at. Kelime kutusu: S1 ve S2 ilgili bölüm.
- **Notability / media-coverage padding** — Kaynak listeleme, kaynak türü sayma, dijital varlık beyanı. Düzeltme: bağlamı olan tek somut olguyu tut, listeyi at. Bağlam uydurulmaz.
- **Superficial analysis (present-participle padding)** — Cümle sonuna eklenen, kanıtsız önem iddia eden "-ing" cümlecikleri. Düzeltme: kes, ya da kaynakta varsa gerçek olguya çevir.
- **Promotional / press-release tone** — Ansiklopedik ton istenirken reklam/seyahat rehberi diline kayma. Düzeltme: akran sesi, ölçülebilir davranış cümlesi.
- **Cultural-heritage over-emphasis** — Kültür/miras konularında önemin sürekli hatırlatılması.

## 2.2 Kaynak ve doğruluk

- **Weasel attribution** — Görüşü belirsiz otoriteye atfetmek. Düzeltme: metin başkasınınsa atıf korunur, kullanıcıya işaretlenir; bu koşuda üretiliyorsa kaynak isimlendirilir, kaynak yoksa cümle kesilir/yazılmaz. Kaynak asla uydurulmaz.
- **Exaggerated source quantity** — Bir-iki kaynağı yaygın görüş gibi sunmak; tek kişiye çoğul atıf; eksik örnek listesini kapsayıcı göstermek.
- **Knowledge-cutoff disclaimer** — "Bilgi şu tarihe kadar geçerli" ifadesinin içerikte kalması.
- **Speculative gap-filling** — Kaynak bulunamadığına dair paragraf + boşluğu kapatan makul uydurma; kişisel yaşamda kalıp "düşük profil" ifadeleri. Düzeltme: bilinmeyeni bilinmeyen olarak yaz veya cümleyi kes.
- **Hallucinated apparatus** — Var olmayan kategori/şablon/parametre; çözülemeyen DOI; geçersiz ISBN checksum'ı; sayfa numarasız kitap atfı; metni doğrulamayan sayfa numarası; gövdede kullanılmayan named ref; kırık dış bağlantı kümesi.

## 2.3 Cümle ve sözdizimi

- **Copula avoidance** — "is/are/has" yerine dolambaçlı yapı. Düzeltme: düz kopula.
- **Negative parallelism** — "not only X but also Y", "not X, it's Y", "X rather than Y"; cümle sonuna eklenen kırpık negasyon. Düzeltme: olumlu iddiayı doğrudan kur.
- **Rule of three** — Anlam gerektirmeyen üçlü gruplama. Düzeltme: gerçek sayı.
- **Elegant variation (synonym cycling)** — Aynı şeye her seferinde başka ad. Düzeltme: terimi tekrarla.
- **False ranges** — Anlamlı ölçek üzerinde olmayan "X'ten Y'ye".
- **Passive voice / subjectless fragments** — Failin gizlenmesi, öznenin düşürülmesi.
- **Parataxis** — Bağlaçsız art arda kısa deklaratif cümleler. Düzeltme: yan cümle, bağlaç, noktalı virgülle ilişkiyi göster. Eşik: S3.
- **Staccato contrast / manufactured punchline** — Her cümlenin kapanış repliği gibi inmesi; dram için kısa parça yığmak.
- **Colon-reveal** — İsim öbeği + iki nokta + sahnelenmiş ödül.
- **Aphorism formula** — Sıradan iddiayı özdeyişe çevirmek. Kapanış özdeyişi cilalanmaz, silinir.
- **Uniform sentence length** — Ritim tekdüzeliği. Eşik: S3.

## 2.4 Ton ve söylem

- **Signposting** — Yapılacak şeyi yapmadan önce duyurmak.
- **Fragmented header** — Başlığı tekrar eden tek satırlık ısınma cümlesi.
- **Persuasive authority trope** — Sıradan noktayı "asıl mesele şu" tarzı derinlik iddiasıyla sunmak.
- **Conversational rhetorical opener** — Sahte samimi hook, teatral duraklama, kendi cevapladığı soru.
- **Sycophancy** — Aşırı olumlu, hoşnut etmeye çalışan dil.
- **Excessive hedging** — Aynı cümlede yığılan niteleyiciler.
- **False balance** — Gerçek karşı argüman değil, denge görüntüsü için konan niteleme.
- **Performative empathy** — Kalıp anlayış gösterisi.
- **Teacher voice** — Okurun bildiğini açıklamak, bariz terim tanımı.
- **Generic positive / hollow conclusion** — Belirsiz iyimser kapanış, metni tekrarlayan özet paragraf, "zorluklar → gelecek görünümü" kalıbı.
- **Collaborative communication artifact** — Sohbet yazışması cümlelerinin içerikte kalması.

## 2.5 Biçim ve tipografi

- **Em dash / en dash aşırı kullanımı** — Virgül, parantez, iki nokta yerine tire; genelde boşlukla çevrili. Düzeltme sırası: nokta → virgül → iki nokta → parantez → cümleyi yeniden kur. Katılık ve oran: S2/S3/S4.
- **Title Case başlık** → sentence case.
- **Mekanik boldface** — Seçilen ifadenin her geçişini kalınlaştırmak.
- **Inline-header vertical list** — "**Terim**: açıklama" maddeleri.
- **Emoji as formatting** — Başlık/madde imi önünde emoji.
- **Curly quotes / apostrophes** → düz karşılığı.
- **Skipped heading levels**; **her bölüm arasında yatay çizgi**.
- **Markdown sızıntısı** — Markdown desteklemeyen bağlama (wikitext, e-posta, DM, SMS, düz metin) yıldız, hash, fenced code block taşımak.
- **Gereksiz küçük tablo** — Düzyazı/infobox ile daha iyi ifade edilecek tablo.
- **Copy-paste artifact** — Model iç biçimlendirme kodlarının metinde kalması. String listesi: S1/S5.
- **Placeholder** — Doldurulmamış şablon alanı, placeholder tarih, "eklenirse" yorumu.

## 2.6 Yapısal kalıplar

- **Rigid outline** — Her konuya uyan sabit bölüm iskeleti.
- **Formula section** — "Zorluklar" + "gelecek görünümü" çifti; "X and Y" kalıp başlıklar.
- **Five-paragraph essay** — intro-body-body-body-conclusion.
- **Identical paragraph structure** — Her paragraf topic sentence → açıklama → örnek → geçiş.
- **Section summary** — Az önce söyleneni tekrarlayan bölüm sonu özeti.
- **Lead treating a title as a proper noun** — Özel ad olmayan başlığı gerçek varlık gibi tanımlamak.

## 2.7 Bağlam işaretleri (metnin dışı)

- Düzenleme özeti: resmî, birinci tekil, kısaltmasız paragraf; politika metnini yankılar; "ensured/avoided" beyanı.
- Yorumlarda: uydurma politika kısayolu, gereksiz şablon transclude, uzun yorumu başlıklı bölümlere ayırma, AI kullanımını emek beyanıyla küçümseme, kaynağa dair eleştiriyi "spekülasyon" diye reddetme.
- Üslupta ani sıçrama; kullanıcı konumu ile İngilizce varyantının uyuşmaması.
- Kullanıcı sayfası ve tanıtım metninde kalıp bölüm başlıkları.
- Hızlı, çok sayıda, birbiriyle alakasız içerik üretimi.

---

# BÖLÜM 3 — EPİSTEMİK KURALLAR

1. Tek işaret kanıt değildir. Karar kümelenmeye dayanır: aynı kısa pasajda birbirinden bağımsız birkaç desen.
2. İşaret sorunun göstergesidir. Yalnız işareti silme; asıl sorunu (kaynaksız iddia, uydurma atıf, tarafsızlık ihlali) düzelt.
3. Dedektör skoru tek başına gerekçe değildir.
4. "Bana AI gibi geldi" tek başına gerekçe değildir.
5. Yüzde/olasılık skoru üretilmez; çıktı, metinle karşılaştırılabilir desen listesidir.
6. Her flag, ifadenin birebir alıntısını ve eşleştiği desen adını ister; "genel ton" gerekçe değildir.
7. ChatGPT'nin herkese açılma tarihinden önceki metinde AI elenir (tarih S1'den).
8. Tek işaretli kelimeyi temizlemek için cümle bozulmaz, bilgi silinmez.
9. Sesi olmayan, tekdüze, kusursuz organize metin de izdir.

---

# BÖLÜM 4 — YANLIŞ POZİTİFLER

Tek başına işaret değil:

- Kusursuz dilbilgisi, tutarlı biçem.
- Gündelik ve resmî kaydın karışması.
- Kuru/"robotik" düzyazı — belirli desen yoksa.
- Resmî/akademik/süslü dağarcık — yalnız kaynaktaki belirli kelimeler işarettir.
- Mektup biçimli açılış/kapanış.
- İzole geçiş kelimesi — yığılmadıkça.
- Kıvrık tırnak.
- Em dash.
- Tek kısa vurgu cümlesi.
- Kaynaksız iddia.
- Doğru ve karmaşık biçimlendirme.
- İkincil metin: alıntı, başlık, özel ad veya bahsi geçen (kullanılmayan) ifadedeki kalıplar yeniden yazılmaz.

İnsan yazımı işaretleri — korunur:

- Spesifik, olağandışı, uydurulması zor detay.
- Karışık duygu, çözülmemiş gerilim.
- Döneme/alt kültüre bağlı referans.
- Yazarın savunabildiği editoryal karar.
- Cümle ve paragraf uzunluğunda gerçek çeşitlilik.
- Gerçek yan cümle, parantez, kendini düzeltme.

---

# BÖLÜM 5 — SÜREÇ KURALLARI

## 5.1 Bilgi bütünlüğü

1. Kaynakta olmayan olgu, isim, sayı, tarih, alıntı, atıf eklenmez; mevcut olgu, sayı, isim ve yazarın pozisyonu değişmez.
2. Belirsiz iddia spesifikle değiştirilebilir; spesifik yalnız kaynaktan veya kullanıcıdan gelir.
3. Kaynaksız iddia süslenmez: isimlendirilir veya kesilir.
4. Uzunluk için doldurma yapılmaz.
5. Yasaklı kelime başka yasaklı kelimeyle değiştirilmez.
6. Kod blokları, frontmatter, veri, link hedefleri, alıntılar elle sürülmez.

## 5.2 Ses

1. Kullanıcı kendi yazısından örnek verirse analiz edilir, taklit edilir; örnek stil kurallarının üstündedir (em dash dâhil).
2. Örnek yoksa ton içeriğe göre seçilir: ansiklopedik/teknik/hukuki metinde nötr ve düz; görüş veya birinci şahıs eklenmez.
3. Blog/deneme/görüş metninde veya ses örneği verildiyse kişilik gösterilir (duruş, kararsızlık, mizah, düzensiz ritim); başka durumda eklenmez. Kişilik olgu eklenerek yaratılmaz.
4. Argo, sahte gündelikleşme, uydurma anekdot eklenmez.
5. Belirli kişi adına yazılıyorsa onun alışkanlıkları esas: uzunluk, mizah türü, asla söylemeyeceği şeyler, platform farkı.

## 5.3 Akış

1. Girdiyi tamamen oku.
2. Bu metindeki en belirgin desenleri tespit et; eforu oraya ver.
3. Taslak yaz; sesli okunuşta akıyor mu, cümle uzunluğu değişiyor mu, basit yapı tercih edilmiş mi kontrol et.
4. Sor: bariz AI yapan ne kaldı; rewrite kaynakta olmayan bir şey söylüyor mu.
5. Düzeltmeleri tek geçişte uygula ve çeşitlendir; her kuralı her örneğe mekanik uygulama.
6. Teslim öncesi checklist'i koş (S5).
7. Kurallar sessizce uygulanır; çıktıda kural adı anılmaz, süreç anlatılmaz.

## 5.4 Teslim biçimi

- **Yapıştırılmış metin**: taslak + kalan izlerin kısa listesi + nihai metin.
- **Dosya**: döngü içeride koşar, dosya yerinde nihai metinle yazılır, konuşmaya kısa değişiklik özeti.
- **Gömülü (başka görevin adımı)**: yalnız nihai metin.
- **Tespit modu**: rewrite yok; alıntı + desen adı listesi. İstenirse teşhis ve rewrite ayrı verilir.

---

# BÖLÜM 6 — ÇATIŞMA ÇÖZÜMÜ

1. **Kelime sınıflandırması**: S1 kazanır.
2. **Sayısal eşik** (em dash oranı, ardışık cümle sınırı): üretimde S3, yeniden yazmada S2/S4. Uygulanan kaynak çıktıda belirtilir; oranlar ortalanmaz.
3. **İçerik silme**: yeniden yazmada hiçbir argüman/veri silinmez. Tek istisna kaynaksız iddianın kesilmesi; kullanıcıya bildirilir.
4. Kaynak kendi içinde çelişirse (güncellenmiş, bölüm numaraları kaymış) en güncel sürümü esas al; eski kopya (mirror repo) atlanır.
