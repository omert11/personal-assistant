#!/usr/bin/env bash
# personal-assistant setup entrypoint
# uv yoksa kurar, sonra setup.py'yi rich/questionary dep'leriyle çalıştırır.
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v uv >/dev/null 2>&1; then
  echo "uv bulunamadı, kuruluyor..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # uv yolu güncel shell için
  if [ -f "$HOME/.local/bin/env" ]; then
    . "$HOME/.local/bin/env"
  else
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

exec uv run "$HERE/scripts/setup.py" "$@"
