# Workflow

## Görev Takibi (TaskCreate / TaskUpdate) — Çok Adımlı İşlerde Zorunlu

Çok adımlı bir iş (3+ adım, birden fazla dosya, veya önceden planlanan bir akış) başladığında **TaskCreate ile görev listesi oluştur** ve süreç boyunca canlı tut. Amaç: kullanıcı akışın nerede olduğunu görsün, hiçbir adım unutulmasın.

- **Başlarken**: İşi adımlara böl, her adım için `TaskCreate` ile görev aç. Akış net değilse önce planla, sonra görevleri oluştur.
- **İlerlerken**: Bir adıma başlarken o görevi `TaskUpdate` ile `in_progress`, bitirince `completed` işaretle. Aynı anda yalnızca bir görev `in_progress` olsun.
- **Yeni iş çıkarsa**: Akış sırasında ortaya çıkan ek iş/alt görev için anında yeni `TaskCreate` aç — listeyi gerçeği yansıtacak şekilde güncelle.
- **Bitince**: Tüm görevler `completed` olmalı; yarım kalan/iptal olan varsa durumunu net bırak (görmezden gelme).

### Ne Zaman Gerekmez
- Tek-shot küçük işler (tek dosya düzenleme, tek komut, tek soru yanıtı, trivial istek) — görev listesi gereksiz yük, açma.
- Genel ölçü: İş zihinde tek adımda tamamlanıyorsa görev açma; izlenmesi gereken birden çok bağımsız adım varsa **mutlaka aç**.

## Hedef Belirleme (`/goal`) — Net + Uzun Hedefte Öner

Kullanıcı agente **doğrulanabilir bir bitiş durumu olan, çok turlu / uzun soluklu bir hedef** verdiğinde (ör. "tüm testler geçene kadar migrate et", "bütün eksik çeviriler bitene kadar çevir", "issue backlog'u boşalana kadar kapat"), bu hedefi `/goal` ile tanımlamayı **kullanıcıya öner** — kendiliğinden set etme.

`/goal <koşul>` Claude'u koşul sağlanana kadar **turlar arası kendiliğinden** çalıştırır (her tur sonunda küçük model koşulu denetler, token harcar, oturumu açık tutar). Bu yüzden kararı kullanıcı verir:

- **Öner**: Hedef tek ölçülebilir bir bitiş durumuna sahipse ve birden çok tur sürecekse, `AskUserQuestion` ile sor (header: "Goal", question: "Bu hedefi `/goal` ile koşula bağlayıp otonom ilerleteyim mi?", options: ["Evet, /goal ile bağla", "Hayır, normal ilerle"]). Onay gelirse koşulu `/goal <koşul>` olarak öner/kur.
- **Koşulu iyi yaz**: Tek ölçülebilir end-state + nasıl kanıtlanacağı (ör. "`pytest` exit 0", "`git status` temiz") + değişmemesi gerekenler. Sınır için "or stop after N turns" ekle. Maks 4000 karakter. Evaluator komut çalıştırmaz — koşul yalnızca Claude'un transcript'e yansıttığıyla doğrulanabilir olmalı.
- **Öner­me**: Tek-shot/kısa işler, bitiş durumu belirsiz/öznel hedefler (ör. "kodu güzelleştir"), veya kullanıcının her adımı görmek istediği işler. Bunlarda görev takibi (yukarıdaki TaskCreate akışı) yeterli.
- **`/goal` vs Görev Takibi**: İkisi dik. `/goal` = otonom turlar arası ilerleme (kullanıcı onaylı); TaskCreate = adımların görünür takibi. Uzun hedefte ikisi birlikte kullanılabilir.

## Teammate Kullanımı
- Kullanıcı "teammate", "takım kur", "team kur", "ekip kur" dediğinde **mutlaka TeamCreate** kullan, sub-agent değil
- Teammate'ler birbirleriyle mesajlaşabilir, görev listesi paylaşır ve koordineli çalışır
- Kullanıcı belirtmiyorsa → Sub-Agent yeterli

## Sub-Agent Çağırma — MUTLAK KURAL
- **Kullanıcı açıkça "subagent", "sub-agent", "alt agent", "agent ile yap" demediği sürece kendi inisiyatifinle sub-agent çağırmak YASAK.**
- Sub-agent çağırman gerektiğini düşünüyorsan **önce `AskUserQuestion` ile kullanıcıya sor** (header: "Sub-Agent", question: "Bu işi sub-agent ile yapmamı ister misin?", options: ["Evet, sub-agent kullan", "Hayır, kendin yap"]).
- Onay alınmadan `Task` tool veya herhangi bir `Agent` çağrısı **kesinlikle yapılmaz**.
- Bu kuralın istisnası yok — "hızlı olur", "paralel çalışır", "context korunur" gibi gerekçeler geçersiz. Önce sor, sonra çağır.

### İstisnalar — Onay Gerekmez
Aşağıdaki durumlarda agent **doğrudan çağrılır, soru sorulmaz, ertelenmez**:
- **Skill içinden tetiklenen agent çağrıları** (örn. `obsidian-init` → `obsidian-initializer`, `obsidian-note` → `obsidian-writer` append, `crawl2md` → `web-scrape-cleaner`). Skill protokolü gereği çalışır.
- **Bir agent'ın kendi tanımında belirtilen alt agent çağrıları** (örn. orchestrator agent'ın koordine ettiği alt agent'lar).
- **Hook veya otomasyon akışı tarafından tetiklenen agent'lar** (örn. Stop hook → writer).
- Kısaca: agent çağrısı önceden tanımlanmış bir akışın (skill, agent definition, hook) parçasıysa **direkt yürüt**, kullanıcıya sorma.

## Bloklayan İş Çalıştırma Modu — Her Zaman Background (İstisnasız)

**Bloklayan veya süreli olabilecek HER iş arka planda çalıştırılır** — subagent, uzun süren Bash komutu, workflow ve benzeri asenkron işler dahil. Bloklayan iş ana akışı dondurur; bunun yerine işi background'a al, kullanıcıya tek cümleyle ne başlattığını söyle ve tamamlanma bildirimini (`task-notification`) bekle.

- **Neden:** İş arka planda çalışırken ana akış bloklanmaz. Sonucu beklemen gerekse bile, foreground yerine background + bildirim beklemek daha sağlıklıdır; harness tamamlanmayı yönetir, akış donmaz, kullanıcı istediği an araya girebilir.
- **Bildirim geldiğinde:** İşin döndürdüğü sonucu/çıktıyı özetle, gerekiyorsa bir sonraki adımı uygula.
- **Çakışma:** Arka planda çalışan işle aynı dosya/konu üzerinde, o çalışırken çakışacak iş yapma.

"Kısa sürer", "tek seferlik", "sonucu hemen lazım" gibi gerekçeler foreground'u haklı çıkarmaz — **bloklayan her iş background.**

### İş Tiplerine Göre Uygulama

- **Subagent (`Agent` tool):** Bir subagent (writer, analiz, code reviewer, explorer, doc-source vb.) **belirli bir görev için çağrıldığında, HER ZAMAN `run_in_background: true` ile** başlatılır. İstisna yoktur — sonucunu beklemen gereken durumda bile foreground (bloklayan) çağrı **hiçbir koşulda kullanılmaz**. Bir sonraki adım subagent çıktısına bağlıysa, paralel yapacak başka iş olmasa bile foreground'a düşme — bildirimi bekle.
- **Bash (`Bash` tool):** Saniyelerce veya daha uzun sürebilen / süreli olan komutlar **`run_in_background: true` ile** çalıştırılır. Örnekler: build (`go build`, `npm run build`, `cargo build`), test suite (`pytest`, `npm test`), bağımlılık kurulumu (`uv pip install`, `npm install`, `brew install`), dev server / watch (`npm run dev`, `manage.py runserver`), deploy / migration (`manage.py migrate`, `fastlane`), log tail (`tail -f`, uzun `grep`/`find`), uzun veri işleme (büyük dosya dönüştürme, reindex). Çıktıyı bekleyeceksen bile background başlat, `task-notification` ile sonucu al. Süresi belirsiz/uzun olabilecek bir komutta tereddüt edersen → background.
- **Workflow (`Workflow` tool):** Zaten background çalışır (tool çağrısı anında döner, tamamlanınca `task-notification` gelir). Foreground'a zorlamaya çalışma; sonucu bildirimle topla.

### İstisna — Kısa/Anlık Komutlar Foreground Kalır

Aşağıdaki Bash komutları foreground çalıştırılır (background gereksiz gecikme yaratır):

- **Sub-saniye, yan etkisiz, çıktısı anında lazım olan okuma komutları:** `ls`, `pwd`, `git status`, `git log`, `git diff`, `cat` (dedicated tool yoksa), kısa `grep`/`rg`, `which`, version check (`--version`), `echo`, tek kayıt DB/CLI sorgusu.
- **Genel ölçü:** Komutun normalde ~birkaç saniyenin altında bitmesi **kesinse** ve çıktısı bir sonraki adımın ön koşuluysa → foreground. Aksi her durumda → background.
- Bu istisna **yalnızca Bash içindir** — subagent ve workflow her zaman background, istisnasız.
