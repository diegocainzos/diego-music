#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="2.46.0"
SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
TARGET="$ROOT/.pi/tools/xcodegen"
BINARY="$TARGET/bin/xcodegen"

if [[ -x "$BINARY" ]] && [[ "$($BINARY --version 2>/dev/null || true)" == *"$VERSION"* ]]; then
  exit 0
fi

TEMP_DIR="$(mktemp -d -t diegomusic-xcodegen.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT
ARCHIVE="$TEMP_DIR/xcodegen.zip"

curl -fsSL \
  "https://github.com/yonaskolb/XcodeGen/releases/download/$VERSION/xcodegen.zip" \
  -o "$ARCHIVE"

ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$SHA256" ]]; then
  echo "La suma SHA-256 de XcodeGen no coincide; instalación cancelada." >&2
  exit 1
fi

unzip -q "$ARCHIVE" -d "$TEMP_DIR"
rm -rf "$TARGET"
mkdir -p "$(dirname "$TARGET")"
mv "$TEMP_DIR/xcodegen" "$TARGET"
chmod +x "$BINARY"

echo "XcodeGen $VERSION instalado localmente en .pi/tools/xcodegen."
