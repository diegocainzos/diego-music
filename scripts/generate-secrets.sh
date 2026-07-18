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
from urllib.parse import urlsplit

env_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
requested = {
    "YOUTUBE_DATA_KEY",
    "AUDIO_RESOLVER_BASE_URL",
    "AUDIO_RESOLVER_API_TOKEN",
}
values: dict[str, str] = {}

for raw_line in env_path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("export "):
        line = line[7:].lstrip()
    match = re.match(r"^([A-Z0-9_]+)\s*=\s*(.*)$", line)
    if not match or match.group(1) not in requested:
        continue
    candidate = match.group(2).strip()
    if len(candidate) >= 2 and candidate[0] == candidate[-1] and candidate[0] in "\"'":
        candidate = candidate[1:-1]
    values[match.group(1)] = candidate

key = values.get("YOUTUBE_DATA_KEY", "")
if not key:
    print("YOUTUBE_DATA_KEY no está declarada o está vacía en .env.", file=sys.stderr)
    raise SystemExit(1)
if not re.fullmatch(r"[A-Za-z0-9_-]+", key):
    print("YOUTUBE_DATA_KEY contiene caracteres no válidos para xcconfig.", file=sys.stderr)
    raise SystemExit(1)

base_url = values.get("AUDIO_RESOLVER_BASE_URL", "")
token = values.get("AUDIO_RESOLVER_API_TOKEN", "")
if bool(base_url) != bool(token):
    print("Configura juntas AUDIO_RESOLVER_BASE_URL y AUDIO_RESOLVER_API_TOKEN.", file=sys.stderr)
    raise SystemExit(1)

if base_url:
    parsed = urlsplit(base_url)
    if re.search(r"[\s$]", base_url):
        print("AUDIO_RESOLVER_BASE_URL contiene caracteres no válidos para xcconfig.", file=sys.stderr)
        raise SystemExit(1)
    if parsed.scheme != "https" or not parsed.netloc or parsed.query or parsed.fragment:
        print("AUDIO_RESOLVER_BASE_URL debe ser HTTPS y no incluir query ni fragmento.", file=sys.stderr)
        raise SystemExit(1)
    base_url = base_url.rstrip("/")

if token and (len(token) < 32 or not re.fullmatch(r"[A-Za-z0-9._~-]+", token)):
    print("AUDIO_RESOLVER_API_TOKEN debe tener 32 caracteres seguros o más.", file=sys.stderr)
    raise SystemExit(1)

for name, value in values.items():
    if any(character in value for character in "\r\n"):
        print(f"{name} contiene caracteres no válidos.", file=sys.stderr)
        raise SystemExit(1)

# En xcconfig, // inicia un comentario. $() conserva las dos barras al expandir.
escaped_base_url = base_url.replace("://", ":/$()/") if base_url else ""
content = (
    "// Generado localmente por scripts/generate-secrets.sh. No versionar.\n"
    f"YOUTUBE_DATA_KEY = {key}\n"
    f"AUDIO_RESOLVER_BASE_URL = {escaped_base_url}\n"
    f"AUDIO_RESOLVER_API_TOKEN = {token}\n"
)

output_path.parent.mkdir(parents=True, exist_ok=True)
temporary = output_path.with_suffix(".xcconfig.tmp")
temporary.write_text(content, encoding="utf-8")
os.chmod(temporary, 0o600)
temporary.replace(output_path)
PY

echo "Configuración local generada sin mostrar credenciales."
