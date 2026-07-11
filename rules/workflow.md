# Workflow

## Görev Takibi (TaskCreate / TaskUpdate) — Çok Adımlı İşlerde Zorunlu

Çok adımlı bir iş (3+ adım, birden fazla dosya, veya önceden planlanan bir akış) başladığında **TaskCreate ile görev listesi oluştur** ve süreç boyunca canlı tut. Amaç: kullanıcı akışın nerede olduğunu görsün, hiçbir adım unutulmasın.

## Subagent / Workflow Kullanımı — İşi Kesinleştir, Çıktıyı Doğrula

Subagent/workflow kullanımı serbesttir — task'in zorluğuna göre kendi inisiyatifinle karar verebilirsin. Büyük bir işi parçalara ayırıp dağıtmak her zaman avantajlıdır. Ancak üç keskin şart var:

### 1. Delegasyondan ÖNCE işi kesinleştir
- **Yapılacak task'i, kapsamını ve beklenen çıktıyı sen tanımla** — task tanımını agent'in kararına/yorumuna bırakma.
- Belirsiz/muğlak tanımla agent çağırmak yasak: prompt'ta girdi, kapsam sınırı, beklenen çıktı formatı ve "ne YAPILMAYACAK" net yazılır.
- İş net değilse önce kendin netleştir (gerekirse kullanıcıya `AskUserQuestion` ile sor), sonra delege et.

### 2. Gereksiz kontrolü önle
- Agent'in görevi kontrol/doğrulama DEĞİLSE ve çıktıyı zaten sen doğrulayacaksan (şart 3), agent'in kendi kendine review/test/doğrulama turları atmasını **önle** — aynı kontrolün hem subagent'ta hem sende koşması zaman/token israfıdır.
- Bunu iş tanımıyla sağla: prompt'a net, kesin bir çerçeve yaz — "yalnızca X'i üret/uygula, review/test/doğrulama yapma; kontrol bende" gibi açık sınır koy.

### 3. Çıktıya "doğru değilmiş" gözüyle bak
- **Subagent/workflow çıktısı doğrulanana kadar güvenilmezdir.** "Yaptım/buldum/geçti" demesi kanıt değildir.
- Çıktıyı kontrol et: iddia edilen dosya değişikliği, test sonucu veya bulguyu **kendin teyit et** (dosyayı oku, testi/komutu doğrula, bulgunun kaynağına bak).
- Birden fazla agent çıktısını birleştirirken çelişkileri ayıkla, tekrarları dedup et, boşlukları kapat — **düzgünce birleştir**, ham çıktıları yan yana yapıştırma.
- **Dürüstçe doğrula**: doğrulayamadığın şeyi doğrulanmış gibi rapor etme; agent hatalı/eksik iş yaptıysa bunu açıkça söyle ve düzelt.
- Skill/agent-tanımı/hook akışının parçası olan çağrılar tanımlandığı gibi yürür — ama çıktı doğrulama şartı onlar için de geçerlidir.

## İş Çalıştırma Davranışları
- Eğer yapacak farklı işlerin varsa ve çalıştırdığın komut seni blokluyorsa arka planda çalıştır ve diğer işlerine odaklan (subagent, uzun süren Bash komutu, workflow ve benzeri)
- Bir bash çalıştırıyorsan ve doğası gereği açık kalması gerekmiyorsa her zaman timeout kullan yanlış giden bir durum varsa tespit etmek kolay olur