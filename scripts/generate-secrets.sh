#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
OUTPUT="$ROOT/Config/Secrets.xcconfig"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Falta .env. Añade YOUTUBE_DATA_KEY localmente." >&2
  exit 1
fi

python3 - "$ENV_FILE" "$OUTPUT" <<'PY'
from pathlib import Path
import os
import re
import sys

env_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
value = None

for raw_line in env_path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("export "):
        line = line[7:].lstrip()
    match = re.match(r"^YOUTUBE_DATA_KEY\s*=\s*(.*)$", line)
    if not match:
        continue
    candidate = match.group(1).strip()
    if len(candidate) >= 2 and candidate[0] == candidate[-1] and candidate[0] in "\"'":
        candidate = candidate[1:-1]
    value = candidate
    break

if not value:
    print("YOUTUBE_DATA_KEY no está declarada o está vacía en .env.", file=sys.stderr)
    raise SystemExit(1)
if any(ch in value for ch in "\r\n"):
    print("YOUTUBE_DATA_KEY contiene caracteres no válidos.", file=sys.stderr)
    raise SystemExit(1)

output_path.parent.mkdir(parents=True, exist_ok=True)
temporary = output_path.with_suffix(".xcconfig.tmp")
temporary.write_text(
    "// Generado localmente por scripts/generate-secrets.sh. No versionar.\n"
    f"YOUTUBE_DATA_KEY = {value}\n",
    encoding="utf-8",
)
os.chmod(temporary, 0o600)
temporary.replace(output_path)
PY

echo "Configuración local generada sin mostrar la clave."
