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
