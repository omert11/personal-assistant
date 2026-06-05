# Learnings

Konuşma sırasında kullanıcı tekrar eden bir komut, iş akışı, yapılandırma bilgisi, sunucu/API bağlantısı veya özel araç kullanımı paylaştığında, `AskUserQuestion` ile sor:
- header: "Kural"
- question: "Bu bilgi bir kural olarak kaydedilebilir. Kural olarak kaydetmemi ister misin?"
- options: ["Evet, kaydet", "Hayır"]

Kullanıcı onaylarsa kuralı `personal-assistant` plugin repo'sundaki `rules/` altına `extension-builder` skill'i ile yaz (yeni `.md` dosyası veya ilgili mevcut kurala ekleme). Oturum başında `load-rules.sh` hook'u bu dosyaları otomatik `~/.claude/rules/` altına materialise eder — ayrı bir kayıt komutu yoktur.
