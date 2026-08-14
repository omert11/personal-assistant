# AI Yazım İzleri — Kural İskeleti + Kaynak Okuma Alanları

Bu belge **kelime listesi tutmaz**. Kelime, ifade, oran, dönem ve model bilgisi eskir; bunlar
her koşuda BÖLÜM 0'daki URL'lerden okunur. Belgede yalnız eskimeyen **desen ve süreç kuralları**
vardır.

---

# BÖLÜM 0 — KAYNAK OKUMA ALANLARI (ZORUNLU)

Aşağıdaki her alan, işe başlamadan **canlı okunur**. Okunmadan kural uygulanmaz.
Okuma yöntemi: `WebFetch` veya `curl -sL <url>`.

## S1 — Wikipedia: Signs of AI writing (ana otorite)

```
https://en.wikipedia.org/w/index.php?title=Wikipedia:Signs_of_AI_writing&action=raw
```

Buradan okunacaklar:
- Her bölümün `Words to watch` kutuları (tam liste)
- `High density of "AI vocabulary" words` bölümündeki dönem kırılımları (hangi kelime hangi model
  döneminde)
- `Internal formatting and reference markup bugs` altındaki araç bazlı imzalar (ChatGPT / Gemini /
  Grok / DeepSeek / Perplexity / sınıflandırılmamış)
- `utm_source=` bölümündeki parametre listesi
- `Differences between LLMs` bölümündeki model karşılaştırması
- `Ineffective indicators` ve `Signs of human writing` bölümlerinin güncel hâli
- `Caveats` altındaki dedektör ve insan yargısı ölçümleri

Notlar:
- `Wikipedia:WikiProject AI Cleanup/AI catchphrases` bu sayfaya `#REDIRECT`'tir; ayrıca okunmaz.
- Sayfa sürekli düzenlenir; kısayol kodları (`WP:AIVOCAB`, `WP:AIDASH` vb.) bölüm adı değişse bile
  hedefe götürür.

## S2 — jooray/humanizer (numaralı desen kataloğu + süreç)

```
https://raw.githubusercontent.com/jooray/humanizer/main/SKILL.md
```

Buradan okunacaklar:
- Numaralı desen bölümlerinin tamamı (her birinde `Words to watch` + before/after)
- `Voice Calibration`, `PERSONALITY AND SOUL`, `Invocation Modes`, `Detect Mode`,
  `Process and Output` bölümleri
- `DETECTION GUIDANCE` altındaki false-positive listesi ve insan yazımı işaretleri
- Em dash bölümünün o sürümdeki katılık seviyesi ve istisnası
- Frontmatter'daki `metadata.version`

Not: `https://raw.githubusercontent.com/blader/humanizer/main/SKILL.md` aynı skill'in geri kalmış
kopyasıdır. Sürüm numaraları karşılaştırılır; büyük olan okunur, diğeri atlanır.

## S3 — jalaalrd/anti-ai-slop-writing (üretim direktifi + yasak listeler)

```
https://raw.githubusercontent.com/jalaalrd/anti-ai-slop-writing/main/skills/anti-ai-slop-writing/SKILL.md
https://raw.githubusercontent.com/jalaalrd/anti-ai-slop-writing/main/skills/anti-ai-slop-writing/references/banned-words.md
```

Buradan okunacaklar:
- `Banned Vocabulary`, `Banned Phrases`, `Banned Sentence/Paragraph Openers` (tam liste)
- `Model-Specific First-Word Tells` (model başına ilk kelime listeleri)
- `Era-Specific AI Vocabulary` (dönem kırılımı)
- `Structural Rules` ve `Punctuation Rules` altındaki **sayısal eşikler** (em dash, ünlem, ellipsis
  sıklığı; ardışık aynı uzunlukta cümle sınırı)
- `Self-Check Before Every Output` maddelerinin güncel sırası ve sayısı

## S4 — bharvey2026/humanise-skill (swap tabloları + editör akışı)

```
https://raw.githubusercontent.com/bharvey2026/humanise-skill/main/SKILL.md
```

Buradan okunacaklar:
- Üç swap tablosu (AI Word / AI Adjective / AI Noun → karşılıkları)
- `Sentence Structure Fixes`, `Tone Fixes`, `Opening & Closing Fixes`, `Transition Fixes`
  altındaki kalıp listeleri
- `Workflow` adımları ve em dash oranı
- Frontmatter'daki `model` / `effort` değerleri

## S5 — haidrrrry/humanize-ai-writing (tells kataloğu + checklist + prompt)

```
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/SKILL.md
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/references/ai-tells.md
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/references/rewrite-rules.md
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/assets/checklist.md
https://raw.githubusercontent.com/haidrrrry/humanize-ai-writing/main/PROMPT.md
```

Buradan okunacaklar:
- `ai-tells.md`: tell kataloğu, model-eğilimli kelime kümeleri, markup artifact listesi,
  "not reliable on their own" maddeleri, composite signal tanımı
- `rewrite-rules.md`: her tell için before/after düzeltme kalıbı ve swap çiftleri
- `checklist.md`: teslim öncesi madde listesi (madde sayısı ve içeriği sürümle değişir)
- `PROMPT.md`: chatbot'a doğrudan yapıştırılabilir sistem promptu; yasak kelime ve kalıp blokları

## S6 — Genişletme kaynakları (isteğe bağlı, konu gerektirdiğinde)

```
https://en.wikipedia.org/w/index.php?title=Wikipedia:Signs_of_AI-generated_comments&action=raw
https://en.wikipedia.org/w/index.php?title=Wikipedia:WikiProject_AI_Cleanup/Guide_and_resources&action=raw
https://en.wikipedia.org/w/index.php?title=Wikipedia:Identifying_LLM_unblock_requests&action=raw
```

Sırasıyla: yorum/tartışma metni işaretleri, temizlik prosedürü, uzun savunma metinlerindeki kalıplar.

## S7 — Okuma protokolü

1. Görev **tespit** ise: S1 zorunlu, S5/`ai-tells.md` zorunlu. Diğerleri opsiyonel.
2. Görev **yeniden yazma / temizleme** ise: S2 zorunlu, S5/`rewrite-rules.md` + `checklist.md`
   zorunlu, S4 swap tabloları opsiyonel.
3. Görev **sıfırdan üretim** ise: S3 zorunlu, S5/`PROMPT.md` zorunlu.
4. Aynı kelime iki kaynakta farklı sınıflandırılmışsa **S1 kazanır** (tek akademik referanslı
   kaynak odur).
5. Sayısal eşik iki kaynakta farklıysa (em dash oranı gibi) hangi kaynağın uygulandığı çıktıda
   belirtilir; ikisi ortalanmaz.
6. Bir URL 404 verirse repo ağacı okunur:
   `https://api.github.com/repos/<owner>/<repo>/git/trees/HEAD?recursive=1` — dosya taşınmış olabilir.
7. Okuma başarısızsa iş **kurallar hatırlanarak yapılmaz**; eksik kaynak açıkça bildirilir.

---

# BÖLÜM 1 — BURADA TUTULMAYAN (her koşuda kaynaktan okunur)

Aşağıdakiler bu belgeye **kopyalanmaz**; kopyalanmışsa silinir:

- Yasak kelime, ifade ve cümle başlangıcı listeleri
- Kelime → karşılık swap tabloları
- Dönem bazlı kelime kırılımları (hangi kelime hangi model kuşağında)
- Model bazlı imzalar: ilk kelime eğilimleri, markup artifact string'leri, UTM parametreleri
- Sayısal eşikler: em dash / ünlem / ellipsis oranları, ardışık cümle sınırları
- Çalışma sonuçları, yüzdeler, ölçümler, tarihler
- Skill sürüm numaraları ve frontmatter değerleri
- Hangi modelin şu an neyi az/çok kullandığı

Gerekçe: bunların hepsi kaynakta güncellenir. Kopyası tutulursa belge sessizce yanlışa döner.

---

# BÖLÜM 2 — DESEN KURALLARI (eskimeyen)

Her desen için: ne olduğu, neden işaret sayıldığı, düzeltmenin yönü. Somut kelime/ifade örneği
için ilgili kaynak okunur.

## 2.1 Anlam şişirme

- **Significance / legacy / broader-trend padding** — Konunun rastgele bir yönünün daha geniş bir
  olguyu temsil ettiğini veya ona katkı sunduğunu söyleyen cümleler. Düzeltme: şeyin ne olduğunu ve
  ne yaptığını yaz, önem yorumunu at. → Kelime kutusu: S1 ilgili bölüm, S2 ilgili desen.
- **Notability / media-coverage padding** — Kaynak listeleme, kaynak türü sayma, dijital varlık
  beyanı. Düzeltme: bağlamı olan tek somut olguyu tut, listeyi at. Bağlam **uydurulmaz**.
- **Superficial analysis (present-participle padding)** — Cümle sonuna eklenen, kanıtsız önem
  iddia eden "-ing" cümlecikleri. Düzeltme: kes, veya kaynakta varsa gerçek olguya çevir.
- **Promotional / press-release tone** — Ansiklopedik ton istense bile reklam veya seyahat rehberi
  diline kayma. Düzeltme: akran sesi; ölçülebilir davranış cümlesi.
- **Cultural-heritage over-emphasis** — Kültür/miras konularında önemin sürekli hatırlatılması.

## 2.2 Kaynak ve doğruluk

- **Weasel attribution** — Görüşün belirsiz otoriteye atfı. Düzeltme: kaynağı isimlendir; kaynak
  yoksa cümleyi kes. Kaynak **asla uydurulmaz**.
- **Exaggerated source quantity** — Bir-iki kaynağı yaygın görüş gibi sunma; tek kişi atıfta
  bulunulurken çoğul kullanma; örnek listesini eksik/örnekleyici gösterme.
- **Knowledge-cutoff disclaimer** — Bilginin belirli bir tarihe kadar geçerli olduğunu söyleyen
  metnin içerikte kalması.
- **Speculative gap-filling** — Kaynak bulunamayınca bulunamadığına dair paragraf + boşluğu kapatan
  makul uydurma. Kişisel yaşam bilgisinde kalıplaşmış "düşük profil" ifadeleri. Düzeltme:
  bilinmeyeni bilinmeyen olarak yaz veya cümleyi kes.
- **Hallucinated apparatus** — Var olmayan kategori, şablon, parametre; çözülemeyen DOI, geçersiz
  ISBN checksum'ı, sayfa numarasız kitap atfı, metni doğrulamayan sayfa numarası, gövdede
  kullanılmayan named ref, kırık dış bağlantı kümesi.

## 2.3 Cümle ve sözdizimi

- **Copula avoidance** — "is/are/has" yerine ayrıntılı yapı. Düzeltme: düz kopula.
- **Negative parallelism** — Üç biçimi: "not only X but also Y", "not X, it's Y", ters biçim
  "X rather than Y". Ayrıca cümle sonuna eklenen kırpık negasyon parçaları. Düzeltme: olumlu
  iddiayı doğrudan kur.
- **Rule of three** — Anlam gerektirmediği hâlde üçlü gruplama. Düzeltme: gerçek sayıyı kullan.
- **Elegant variation (synonym cycling)** — Aynı şeye her seferinde başka ad. Düzeltme: terimi
  tekrarlat.
- **False ranges** — Anlamlı bir ölçek üzerinde olmayan "X'ten Y'ye" yapıları.
- **Passive voice / subjectless fragments** — Failin gizlenmesi veya öznenin düşürülmesi.
- **Parataxis** — Arka arkaya bağlaçsız kısa deklaratif cümleler. Düzeltme: yan cümle, bağlaç,
  noktalı virgül ile ilişkiyi göster. (Eşik değeri S3'ten okunur.)
- **Staccato contrast / manufactured punchline** — Her cümlenin kapanış replikası gibi inmesi;
  kısa parçaların dram üretmek için yığılması.
- **Colon-reveal** — İsim öbeği + iki nokta + sahnelenmiş ödül.
- **Aphorism formula** — Sıradan iddianın yeniden kullanılabilir özdeyişe çevrilmesi. Kapanış
  özdeyişi cilalanmaz, silinir.
- **Uniform sentence length** — Ritim tekdüzeliği. (Eşik S3'ten okunur.)

## 2.4 Ton ve söylem

- **Signposting** — Yapılacak şeyin yapılmadan önce duyurulması.
- **Fragmented header** — Başlığı tekrar eden tek satırlık ısınma cümlesi.
- **Persuasive authority trope** — "Asıl mesele şu" tarzı derinlik iddiasıyla sıradan bir noktanın
  sunulması.
- **Conversational rhetorical opener** — Sahte samimi hook, teatral duraklama, kendi kendine
  cevaplanan soru.
- **Sycophancy** — Aşırı olumlu, hoşnut etmeye çalışan dil.
- **Excessive hedging** — Aynı cümlede yığılan niteleyiciler.
- **False balance** — Gerçek karşı argüman değil, denge görüntüsü için konmuş niteleme.
- **Performative empathy** — Kalıplaşmış anlayış gösterisi.
- **Teacher voice** — Okurun bildiğinin açıklanması, bariz terim tanımı.
- **Generic positive conclusion / hollow conclusion** — Belirsiz iyimser kapanış, metni tekrarlayan
  özet paragraf, "zorluklar → gelecek görünümü" kalıbı.
- **Collaborative communication artifact** — Sohbet yazışmasına ait cümlelerin içerik içinde
  kalması.

## 2.5 Biçim ve tipografi

- **Em dash / en dash aşırı kullanımı** — İnsanın virgül, parantez, iki nokta koyacağı yerde tire;
  genelde boşlukla çevrili. Düzeltme sırası: nokta → virgül → iki nokta → parantez → cümleyi
  yeniden kur. (Katılık seviyesi ve sayısal oran kaynağa göre değişir; S2/S3/S4'ten okunur.)
- **Title Case başlıklar** — sentence case'e çevrilir.
- **Mekanik boldface** — Seçilen ifadenin her geçişinin kalınlaştırılması.
- **Inline-header vertical list** — "**Terim**: açıklama" biçimli madde listeleri.
- **Emoji as formatting** — Başlık veya madde imi önünde emoji.
- **Curly quotes / apostrophes** — Düz karşılıklarına çevrilir. Tek başına kanıt değildir.
- **Skipped heading levels**, **her bölüm arasına yatay çizgi**.
- **Markdown sızıntısı** — Markdown'ın desteklenmediği bağlama (wikitext, e-posta, DM, SMS, düz
  metin) yıldız, hash, fenced code block taşınması.
- **Gereksiz küçük tablolar** — Düzyazı veya infobox ile daha iyi ifade edilecek tablolar.
- **Copy-paste artifact** — Model iç biçimlendirme kodlarının metinde kalması. (String listesi
  S1/S5'ten okunur.)
- **Placeholder** — Doldurulmamış şablon alanları, placeholder tarihler, "eklenirse" yorumları.

## 2.6 Yapısal kalıplar

- **Rigid outline** — Her konuya uyan sabit bölüm iskeleti.
- **Formula section** — "Zorluklar" + "gelecek görünümü" bölüm çifti; "X and Y" biçimli kalıp
  başlıklar.
- **Five-paragraph essay** — intro-body-body-body-conclusion tam kalıbı.
- **Identical paragraph structure** — Her paragrafın topic sentence → açıklama → örnek → geçiş
  kalıbını izlemesi.
- **Section summary** — Az önce söyleneni tekrarlayan bölüm sonu özeti.
- **Lead treating a title as a proper noun** — Özel ad olmayan başlığın gerçek bir varlık gibi
  tanımlanması.

## 2.7 Bağlam işaretleri (metnin dışı)

- Düzenleme özetlerinin resmî, birinci tekil, kısaltmasız paragraflar olması; politika metnini
  yankılaması; "ensured/avoided" beyanları.
- Yorumlarda: uydurma politika kısayolu, gereksiz şablon transclude, uzun yorumun başlıklı
  bölümlere ayrılması, AI kullanımının emek beyanıyla küçümsenmesi, kaynağa dair eleştirinin
  "spekülasyon" diye reddi.
- Üslupta ani sıçrama; kullanıcı konumu ile İngilizce varyantının uyuşmaması.
- Kullanıcı sayfası ve tanıtım metinlerinde kalıplaşmış bölüm başlıkları.
- Hızlı, çok sayıda, birbiriyle alakasız içerik üretimi.

---

# BÖLÜM 3 — EPİSTEMİK KURALLAR (eskimeyen)

1. **Tek işaret kanıt değildir.** Karar kümelenmeye (cluster) dayanır: aynı kısa pasajda birbirinden
   bağımsız birkaç desenin birlikte düşmesi.
2. **Liste betimleyicidir, buyurucu değil.** İşaretler sorunun kendisi değil, sorunun göstergesidir.
   Yalnız işareti silmek, asıl sorunu (kaynaksız iddia, uydurma atıf, tarafsızlık ihlali) gizler.
3. **Dedektör araçları tek başına yeterli değildir.** Hata oranları önemsiz değil; paraphrase ve
   biçim değişiminden etkilenirler. Skor tek başına gerekçe olmaz.
4. **İnsan yargısı da zayıftır.** Ölçümler S1'den okunur; ölçüm ne olursa olsun "bana AI gibi geldi"
   tek başına gerekçe değildir.
5. **Yüzde/olasılık skoru üretilmez.** Çıktı, kullanıcının metinle karşılaştırabileceği desen
   listesi olur.
6. **Her flag alıntı ister.** Rahatsız eden ifade birebir alıntılanır ve eşleştiği desen adlandırılır;
   "genel ton" gerekçe değildir.
7. **İnsan dili LLM'den etkileniyor.** İşaretlerin ayırt ediciliği zamanla düşer; kelime listeleri
   yakalandıkça kullanımdan düşer. Bu yüzden liste ezberlenmez, okunur.
8. **Kaynak yaşı bir eleme kriteridir.** ChatGPT'nin herkese açıldığı tarihten önceki metinde AI
   elenir. (Tarih S1'den okunur.)
9. **Aşırı düzeltme kendi izini bırakır.** Tek bir işaretli kelimeyi temizlemek için cümle bozulmaz,
   bilgi silinmez.
10. **Sterillik de bir izdir.** Sesi olmayan, tekdüze, kusursuz organize metin en az slop kadar
    bellidir.

---

# BÖLÜM 4 — YANLIŞ POZİTİF KURALLARI (eskimeyen)

Tek başına işaret sayılmayanlar:

- Kusursuz dilbilgisi ve tutarlı biçem — profesyonel yazar veya editörden geçmiş metin.
- Gündelik ve resmî kaydın karışması — teknik alan, yaş, oyunbazlık, nörodiverjans, çok yazarlılık.
- "Düz" veya "robotik" düzyazı — belirli desenler yoksa yalnızca kuru yazıdır.
- Resmî/akademik/süslü kelime dağarcığı — model *belirli* kelimeleri sever, tüm resmî dili değil.
- Mektup biçimli açılış/kapanış.
- İzole geçiş kelimeleri — yığılmadıkça işaret değil.
- Kıvrık tırnaklar — işletim sistemi, kelime işlemci ve CMS varsayılanları bunu üretir.
- Em dash tek başına — birçok editör ve gazeteci sık kullanır.
- Tek kısa vurgu cümlesi.
- Kaynaksız iddia — web'in çoğu kaynaksızdır.
- Doğru ve karmaşık biçimlendirme — görsel editör ve şablonlar temiz çıktı verir.
- İkincil metin — alıntı, başlık, özel ad veya tartışılan (kullanılmayan) ifade içindeki kalıplar
  yeniden yazılmaz.

Karşı taraf — insan yazımının korunacak işaretleri:

- Spesifik, olağandışı, uydurulması zor detay.
- Karışık duygular, çözülmemiş gerilim.
- Döneme ve alt kültüre bağlı referanslar.
- Yazarın savunabildiği editoryal kararlar.
- Cümle ve paragraf uzunluğunda gerçek çeşitlilik.
- Gerçek yan cümleler, parantezler, kendini düzeltmeler.

---

# BÖLÜM 5 — SÜREÇ KURALLARI (eskimeyen)

## 5.1 Bilgi bütünlüğü

1. Kaynakta olmayan hiçbir olgu, isim, sayı, tarih, alıntı veya atıf rewrite'a girmez.
2. Belirsiz iddia spesifikle değiştirilebilir; spesifik ancak kaynaktan veya kullanıcıdan gelir.
3. Kaynaksız iddia süslenmez: ya isimlendirilir ya kesilir.
4. Olgular, sayılar, isimler ve yazarın pozisyonu değişmez.
5. Uzunluk tutturmak için doldurma yapılmaz.
6. Bir yasaklı kelime başka bir yasaklı kelimeyle değiştirilmez.
7. Kod blokları, frontmatter, veri, link hedefleri ve alıntılar elle sürülmez.

## 5.2 Ses

1. Kullanıcı kendi yazısından örnek verirse örnek analiz edilir ve taklit edilir; **örnek, stil
   kurallarının üstündedir** (em dash kuralı dâhil).
2. Örnek yoksa hedef ton içeriğe göre seçilir: ansiklopedik/teknik/hukuki metinde nötr ve düz olan
   doğru insan sesidir; oraya görüş veya birinci şahıs enjekte edilmez.
3. Blog/deneme/görüş metninde kişilik gösterilir: duruş, kararsızlık, mizah, düzensiz ritim. Bu
   kişilik **olgu eklenerek** yaratılmaz.
4. "İnsan gibi durmak" için argo, sahte gündelikleşme veya uydurma anekdot eklenmez — kendi izidir.
5. Belirli bir kişi adına yazılıyorsa o kişinin alışkanlıkları esas alınır: uzunluk, mizah türü,
   asla söylemeyeceği şeyler, platform farkı.

## 5.3 Akış

1. Girdi tamamen okunur.
2. Bu metindeki en belirgin desenler tespit edilir; efor oraya verilir.
3. Taslak yazılır; sesli okunduğunda akıp akmadığı, cümle uzunluğunun değişip değişmediği, basit
   yapıların tercih edilip edilmediği kontrol edilir.
4. İki soru sorulur: metni bariz biçimde AI yapan ne kaldı; rewrite kaynakta olmayan bir şey
   söylüyor mu.
5. Düzeltmeler tek geçişte uygulanır ve **çeşitlendirilir** — her kural her örneğe mekanik
   uygulanmaz; aşırı düzenleme kendi uncanny valley'sini üretir.
6. Teslim öncesi checklist koşulur (madde listesi S5'ten okunur).
7. Kurallar sessizce uygulanır; çıktıda kural adı anılmaz, süreç anlatılmaz.

## 5.4 Teslim biçimi

- **Yapıştırılmış metin**: taslak + kalan izlerin kısa listesi + nihai metin.
- **Dosya**: döngü içeride koşar, dosya yerinde nihai metinle yazılır, konuşmaya kısa değişiklik
  özeti gider.
- **Gömülü (başka bir görevin adımı)**: yalnız nihai metin. Taslak yok, denetim listesi yok, özet
  yok.
- **Tespit modu**: yeniden yazma yok; alıntı + desen adı listesi. İstenirse teşhis ve rewrite ayrı
  ayrı verilir.

---

# BÖLÜM 6 — ÇATIŞMA ÇÖZÜMÜ (eskimeyen)

Kaynaklar aynı konuda farklı katılık dayatır. Karar kuralları:

1. **Kelime sınıflandırması**: S1 kazanır.
2. **Sayısal eşik** (em dash oranı, ardışık cümle sınırı): görev tipine bağlı kaynak uygulanır —
   üretimde S3, yeniden yazmada S2/S4. Uygulanan kaynak çıktıda belirtilir; iki oran ortalanmaz.
3. **İçerik silme yetkisi**: yeniden yazma görevinde varsayılan "hiçbir argüman/veri silinmez"dir.
   Kaynaksız iddianın kesilmesi bunun tek istisnasıdır ve kullanıcıya bildirilir.
4. **Kişilik ekleme**: varsayılan ekleme yok. Ekleme yalnız kullanıcı ses örneği verdiyse veya metin
   türü (blog/deneme/görüş) gerektiriyorsa yapılır.
5. **Muğlak atıf**: metin başkasının ise atıf **korunur** ve kullanıcıya işaretlenir; metin bu
   koşuda üretiliyorsa isimlendirilir veya yazılmaz.
6. Bir kaynak kendi içinde çelişirse (skill güncellenmiş, bölüm numaraları kaymış) o kaynağın en
   güncel sürümü esas alınır; eski kopya (mirror repo) atlanır.
</content>
