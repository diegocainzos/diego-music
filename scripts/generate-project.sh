#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/generate-secrets.sh"

if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN="$(command -v xcodegen)"
else
  "$ROOT/scripts/install-xcodegen.sh"
  XCODEGEN="$ROOT/.pi/tools/xcodegen/bin/xcodegen"
fi

"$XCODEGEN" generate --spec project.yml

echo "DiegoMusic.xcodeproj generado."
