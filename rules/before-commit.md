# Before Commit

- Commit atmadan **önce** mutlaka `/simplify` skill'ini çalıştır (değişen kodun kalitesini, tekrar kullanımını ve verimliliğini kontrol eder)
- Değişiklikler için test yazılıp yazılmadığını kontrol et, yazılmadıysa `AskUserQuestion` ile sor (header: "Test", options: ["Test yaz", "Testsiz devam et"])
- Değişen kodun `~/.claude/rules/` altındaki tüm kurallara uyduğunu doğrula, uymayan varsa düzelt veya `AskUserQuestion` ile raporla
- Eğer bir veya daha fazla Vikunja görevi üzerinde çalışıldıysa, `AskUserQuestion` ile görevleri kapatmak isteyip istemediğini sor
- Asla kullanıcı onayı olmadan commit atma — her zaman önce `AskUserQuestion` ile sor
