# SoloTerm

- Proje ID `CLAUDE.local.md` içinden alınır
- Process yönetimi `solo` **CLI** ile yapılır (`~/.local/bin/solo`, `solo --version` ile doğrula)
- Tekrar eden shell komutları için mutlaka `solo.yml` oluşturulmalı ve komutlar buraya eklenmeli
- Bir komut çalıştırılacaksa ve ileride tekrar kullanılabilecekse: önce `solo.yml`'yi kontrol et, komut varsa Solo üzerinden çalıştır, yoksa önce `solo.yml`'ye ekle sonra Solo üzerinden çalıştır
- `solo.yml` ile tanımlanan komutlar CLI üzerinden başlatılabilir, durdurulabilir, yeniden başlatılabilir ve **çıktısı `solo processes output` ile okunabilir**
