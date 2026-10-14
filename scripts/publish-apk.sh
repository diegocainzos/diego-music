#!/usr/bin/env bash
# Compila el APK de Android y lo deja en web/downloads/ para el botón «DESCARGAR APK».
# No imprime credenciales: solo el SHA-1 público del certificado, para restringir la clave de
# YouTube Data API en Google Cloud a com.diegocainzos.diegomusic.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
  JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
fi
[ -n "${JAVA_HOME:-}" ] && export JAVA_HOME

# SDK de Android: VPS Linux (/opt/android-sdk), Android Studio en Linux o en macOS.
if [ -z "${ANDROID_HOME:-}" ]; then
  for candidate in /opt/android-sdk "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
    if [ -d "$candidate" ]; then
      ANDROID_HOME="$candidate"
      break
    fi
  done
fi
if [ -z "${ANDROID_HOME:-}" ]; then
  echo "No se encontró el SDK de Android; define ANDROID_HOME." >&2
  exit 1
fi
export ANDROID_HOME

cd "$ROOT/android"
./gradlew -Dorg.gradle.jvmargs="-Xmx1536m -Dfile.encoding=UTF-8" --quiet :app:assembleRelease
./gradlew --stop >/dev/null 2>&1 || true

mkdir -p "$ROOT/web/downloads"
cp app/build/outputs/apk/release/app-release.apk "$ROOT/web/downloads/diegomusic.apk"
echo "APK publicado en web/downloads/diegomusic.apk ($(du -h "$ROOT/web/downloads/diegomusic.apk" | cut -f1))."

KEYSTORE="$HOME/.android/debug.keystore"
if [ -f "$KEYSTORE" ]; then
  SHA1="$(keytool -list -v -keystore "$KEYSTORE" -alias androiddebugkey -storepass android -keypass android 2>/dev/null | awk '/SHA1:/ {print $2}')"
  echo "Restringe YOUTUBE_DATA_KEY a: paquete com.diegocainzos.diegomusic, SHA-1 $SHA1"
fi
echo "En el VPS: copia web/downloads/diegomusic.apk a la misma ruta del repositorio (se monta en solo lectura)."
