# Python

- Paket yönetimi için her zaman `uv` kullan (pip değil)

## Venv & Komut Çalıştırma

Python projesinde komut çalıştırmadan önce:

1. `.venv` yoksa `uv` ile oluştur:
   ```bash
   uv venv
   uv pip install -r requirements.txt   # requirements.txt varsa
   uv pip install -r pyproject.toml     # pyproject.toml varsa
   ```
2. `.venv` kurulduktan sonra `source .venv/bin/activate` ile aktive et, sonra normal `python ...` / `pytest ...` / `python manage.py ...` çalıştır
3. **`uv run` kullanma** — venv aktivasyonu ile çalış
