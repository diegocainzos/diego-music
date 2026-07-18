#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$ROOT/ResolverService"
VENV="$SERVICE/.venv"

if [[ ! -x "$VENV/bin/python" ]]; then
  python3 -m venv "$VENV"
fi

"$VENV/bin/pip" install --quiet --requirement "$SERVICE/requirements-dev.txt"
(
  cd "$SERVICE"
  "$VENV/bin/pytest" -q
)
