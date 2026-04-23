# Workflow

## Teammate Kullanımı
- Kullanıcı "teammate", "takım kur", "team kur", "ekip kur" dediğinde **mutlaka TeamCreate** kullan, sub-agent değil
- Teammate'ler birbirleriyle mesajlaşabilir, görev listesi paylaşır ve koordineli çalışır
- Kullanıcı belirtmiyorsa → Sub-Agent yeterli

## Sub-Agent Çağırma — MUTLAK KURAL
- **Kullanıcı açıkça "subagent", "sub-agent", "alt agent", "agent ile yap" demediği sürece sub-agent çağırmak YASAK.**
- Sub-agent çağırman gerektiğini düşünüyorsan **önce `AskUserQuestion` ile kullanıcıya sor** (header: "Sub-Agent", question: "Bu işi sub-agent ile yapmamı ister misin?", options: ["Evet, sub-agent kullan", "Hayır, kendin yap"]).
- Onay alınmadan `Task` tool veya herhangi bir `Agent` çağrısı **kesinlikle yapılmaz**.
- Bu kuralın istisnası yok — "hızlı olur", "paralel çalışır", "context korunur" gibi gerekçeler geçersiz. Önce sor, sonra çağır.
- Skill'ler içinden otomatik tetiklenen agent'lar (örn. `obsidian-writer` append mode) bu kurala dahil değildir — onlar skill protokolü gereği çalışır.
