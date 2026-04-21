# CLI Araçları

## Zed
- `zed dosya.txt` - dosya aç
- `zed dosya.txt:42` - satıra git
- `zed -n` - yeni pencere
- `zed -a` - mevcut workspace'e ekle
- `zed --diff a.ts b.ts` - diff görünümü
- `zed --wait` - kapanana kadar bekle (git editor için)

## Tailscale
- `tailscale status` - cihaz durumları
- `tailscale up` / `tailscale down` - bağlan / kes
- `tailscale ip` - kendi Tailscale IP'ni göster
- `tailscale ping <host>` - cihaza ping at
- NOT: IP Whitelist için hata aldığında tailscale deneyebilirsin

## UV
- `uv venv` - sanal ortam oluştur
- `uv python pin <versiyon>` - Python versiyonu sabitle
- `uv pip install <paket>` - paket kur
- `uv pip install -r requirements.txt` - requirements'tan kur
- `uv pip list` - kurulu paketler
- `uv pip freeze` - freeze
- `uv run <komut>` - venv içinde komut çalıştır

## rsvg-convert
- `rsvg-convert -w 512 -h 512 input.svg -o output.png` - SVG'yi PNG'ye dönüştür (boyut belirterek)
- `rsvg-convert input.svg -o output.pdf` - SVG'yi PDF'e dönüştür
- `rsvg-convert -z 2 input.svg -o output.png` - 2x zoom ile dönüştür
- Kurulum: `brew install librsvg`
