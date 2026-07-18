# DiegoMusic

Cliente educativo y privado para explorar y reproducir música con APIs oficiales de YouTube en iPhone, iPad y macOS. La identidad visual combina Bauhaus digital con controles Hi‑Fi skeuomórficos; no es una aplicación oficial ni está afiliada con YouTube o Google.

## Destinos

- iOS/iPadOS 17 o posterior.
- macOS 13 o posterior.
- Bundle ID: `com.diegocainzos.DiegoMusic`.
- Core Data para biblioteca, playlists, historial y preferencias. SwiftData requiere macOS 14 y no es compatible con el mínimo acordado.

## Configuración local

La clave nunca debe copiarse a Swift, documentación o logs. Declárala únicamente en `.env`:

```text
YOUTUBE_DATA_KEY=valor_local
```

Genera el xcconfig ignorado y el proyecto:

```bash
./scripts/generate-project.sh
```

El script no muestra el valor. `Config/Secrets.xcconfig` y `.env` están excluidos mediante `.gitignore`. Restringe la clave en Google Cloud a YouTube Data API v3 y aplica límites de cuota; una clave dentro de una aplicación cliente no puede considerarse totalmente secreta.

## Proyecto reproducible

`project.yml` es la fuente de verdad. `generate-project.sh` descarga XcodeGen 2.46.0 bajo `.pi/tools/xcodegen`, verifica su SHA-256 y no requiere instalación global. El binario local no se versiona.

```bash
./scripts/generate-project.sh
open DiegoMusic.xcodeproj
```

Para iOS 17 se necesita una versión de Xcode que incluya el SDK correspondiente. Es posible seleccionar Xcode sin modificar el sistema:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Arquitectura

- `DiegoMusic/App`: arranque, entorno e interfaz adaptable.
- `DiegoMusic/Core`: dominio, red y Core Data.
- `DiegoMusic/YouTube`: endpoint, DTOs, mapper y servicio Data API.
- `DiegoMusic/WebPlayer`: IFrame Player oficial y puente Swift–JavaScript.
- `DiegoMusic/PrivacyShield`: reglas, compilación WebKit y laboratorio controlado.
- `DiegoMusic/Design`: sistema visual Bauhaus Hi‑Fi y estados accesibles.
- `Tests/UnitTests`: endpoint, mapeo, errores, cola, mensajes, reglas y persistencia.

## Identidad del reproductor y errores 152/153

YouTube exige que los reproductores embebidos identifiquen la aplicación mediante `HTTP Referer` o un identificador equivalente. DiegoMusic prepara el HTML con el origen `https://com.diegocainzos.diegomusic`, derivado del bundle ID, usa ese mismo valor en `origin` y `widget_referrer`, y aplica `strict-origin-when-cross-origin`.

Los códigos 152/153 en WKWebView suelen indicar que YouTube no pudo validar esa identidad o detectó una discordancia entre `origin` y `Referer`. El reproductor también mantiene un viewport mínimo de 200×200 puntos, como exige la documentación oficial.

Prueba live opcional contra el vídeo oficial de referencia:

```bash
RUN_YOUTUBE_PLAYER_LIVE_TEST=1 \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO \
  -only-testing:DiegoMusicTests/WebResourcesTests/testOfficialPlayerAcceptsBundleIdentity test
```

## PrivacyShield

Modos:

- **Desactivado:** no instala reglas.
- **Equilibrado:** bloquea redes publicitarias conocidas y prioriza la reproducción.
- **Agresivo:** añade patrones de anuncios de YouTube y puede necesitar recuperación.

Las reglas se compilan con `WKContentRuleListStore` antes de recargar el reproductor. El laboratorio incluido demuestra de forma determinista la diferencia entre recursos permitidos y bloqueados. Se pueden importar listas JSON compatibles desde Ajustes.

No es técnicamente posible garantizar el bloqueo permanente de todos los anuncios dentro de un iframe de otro origen: YouTube puede cambiar endpoints y compartir infraestructura entre contenido y publicidad. DiegoMusic aplica bloqueo real de mejor esfuerzo, permite actualizar reglas y ofrece recuperación inmediata sin reemplazar el reproductor oficial ni extraer streams.

## Pruebas

Con Xcode 15 o posterior y sus simuladores instalados:

```bash
./scripts/validate.sh
```

Comprobaciones individuales:

```bash
./scripts/verify-no-secrets.py

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
```

## Capacidades Pi locales

`.pi/settings.json` activa únicamente en este proyecto:

- `pi-subagents`;
- `@upstash/context7-pi`;
- `@narumitw/pi-chrome-devtools`.

OpenSpec está instalado bajo `.pi/openspec`. Ejecuta `/reload` al abrir Pi desde este directorio para registrar herramientas, skills y comandos `/opsx:*`.
