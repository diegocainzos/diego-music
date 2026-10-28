#!/usr/bin/env bash
# Puertas deterministas de feature-loop para DiegoMusic (web, resolutor, Android, iOS/macOS).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
(cd web && npm test && npm run build)
./scripts/verify-no-secrets.py
./scripts/validate-resolver.sh
(cd android && ./gradlew -q :app:testDebugUnitTest :app:assembleDebug)
xcodebuild -quiet -project DiegoMusic.xcodeproj -scheme DiegoMusic -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test
