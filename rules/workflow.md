# Workflow

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

## Sub-Agent Çalıştırma Modu — Her Zaman Background (İstisnasız)

Bir subagent (writer, analiz, code reviewer, explorer, doc-source vb.) **belirli bir görev için çağrıldığında, HER ZAMAN `run_in_background: true` ile arka planda başlatılır.** İstisna yoktur — sonucu beklemen gereken durumlarda bile subagent arka planda çalıştırılır ve tamamlanma bildirimi beklenir. Foreground (bloklayan) çağrı **hiçbir koşulda kullanılmaz**.

- **Neden:** Subagent arka planda çalışırken ana akış bloklanmaz. Sonucu beklemen gerekse bile, foreground yerine background + bildirim beklemek daha sağlıklıdır; harness tamamlanmayı yönetir, akış donmaz, kullanıcı istediği an araya girebilir.
- **Nasıl:** `Agent` çağrısında **daima** `run_in_background: true` ver. Başlattıktan sonra kullanıcıya tek cümleyle ne başlattığını söyle. Bir sonraki adım subagent'ın çıktısına bağlıysa, paralel yapacak başka iş yoksa bile, foreground'a düşme — `task-notification` gelene kadar bekle.
- **Bildirim geldiğinde:** Subagent'ın döndürdüğü sonucu özetle, gerekiyorsa bir sonraki adımı uygula.
- **Çakışma:** Subagent ile aynı dosya/konu üzerinde, o çalışırken çakışacak iş yapma.

"Kısa sürer", "tek seferlik", "sonucu hemen lazım" gibi gerekçeler foreground'u haklı çıkarmaz — **her durumda background.**
