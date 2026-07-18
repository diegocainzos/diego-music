# DiegoMusic

Cliente privado para explorar el catálogo de YouTube y reproducir audio mediante un resolutor propio desplegado en VPS. En iPhone, iPad y macOS usa AVPlayer y una interfaz Bauhaus digital con controles Hi‑Fi; no es una aplicación oficial ni está afiliada con YouTube o Google.

## Destinos

- iOS/iPadOS 17 o posterior.
- macOS 13 o posterior.
- Bundle ID: `com.diegocainzos.DiegoMusic`.
- Core Data para biblioteca, playlists, historial y preferencias. SwiftData requiere macOS 14 y no es compatible con el mínimo acordado.

## Configuración local

Las credenciales nunca deben copiarse a Swift, documentación o logs. Decláralas únicamente en `.env`:

```dotenv
YOUTUBE_DATA_KEY=valor_local
AUDIO_RESOLVER_BASE_URL=https://audio.example.com
AUDIO_RESOLVER_API_TOKEN=token_aleatorio_de_32_caracteres_o_mas
```

`AUDIO_RESOLVER_API_TOKEN` debe coincidir con `DIEGOMUSIC_API_TOKEN` en el VPS. Genera el xcconfig ignorado y el proyecto:

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
- `DiegoMusic/AudioPlayer`: cliente del resolutor, AVPlayer, sesión de audio y controles remotos.
- `DiegoMusic/Design`: sistema visual Bauhaus Hi‑Fi y estados accesibles.
- `ResolverService`: FastAPI, yt-dlp, sesiones opacas, proxy Range y despliegue Docker/Caddy.
- `Tests/UnitTests`: catálogo, configuración, errores, cola, cliente del resolutor y persistencia.

Flujo de reproducción:

```text
YouTube Data API → videoId → VPS privado → sesión de audio opaca → AVPlayer
```

El cliente no recibe la URL upstream de Googlevideo. El VPS conserva esa URL y sus cabeceras únicamente en memoria, y expone un token temporal capaz de atender `GET`, `HEAD` y HTTP Range. No se guarda audio permanentemente.

## VPS privado

Consulta [`ResolverService/README.md`](ResolverService/README.md) para preparar DNS, Docker Compose, Caddy HTTPS, token, actualización de yt-dlp y rotación de credenciales.

Resumen:

```bash
cd ResolverService
cp .env.example .env
# Edita dominio y token sin mostrarlos en logs.
docker compose --file compose.yml up --detach --build
```

El servicio interno no publica el puerto 8080. Solo Caddy expone 80/443 y los access logs permanecen desactivados por defecto.

El resolutor reutiliza resoluciones vigentes, conserva hasta 5 GiB de M4A en un volumen LRU y sirve repeticiones desde disco. La primera reproducción calienta la caché en background; `docker compose down` conserva el volumen.

## Reproducción nativa

- Dock compacto sin vídeo y ampliación sin reiniciar la pista.
- AVPlayer único con progreso, seek, cola y avance automático.
- `AVAudioSession` en categoría `.playback` para iPhone.
- Background audio, pantalla bloqueada y comandos play/pause/anterior/siguiente/seek.
- `MPNowPlayingInfoCenter` con título, canal, duración, posición y velocidad.
- Errores sanitizados: la interfaz nunca muestra credenciales ni URLs firmadas.
- Caché de descriptores en memoria y un reintento automático tras reinicios del resolutor.
- Precarga silenciosa de la siguiente pista de la cola.

## Pruebas

Con Xcode 15 o posterior y sus simuladores instalados:

```bash
./scripts/validate.sh
```

Comprobaciones individuales:

```bash
./scripts/verify-no-secrets.py
ResolverService/.venv/bin/pytest -q ResolverService/tests

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
```

## Instalar en un iPhone

1. Instala una versión de Xcode compatible con el iOS del dispositivo: Xcode 15+ para iOS 17 y Xcode 16+ para iOS 18.
2. Despliega primero el VPS y completa las tres variables de `.env`.
3. Ejecuta `./scripts/generate-project.sh` y abre `DiegoMusic.xcodeproj`.
4. En **Xcode → Settings → Accounts**, añade tu Apple Account.
5. Conecta y desbloquea el iPhone, acepta la confianza y activa **Ajustes → Privacidad y seguridad → Modo de desarrollador**.
6. En el target `DiegoMusic`, abre **Signing & Capabilities**, activa firma automática y selecciona tu Team.
7. Selecciona el iPhone como destino y pulsa **Run** (`⌘R`).
8. Reproduce una canción, bloquea la pantalla y comprueba los controles del sistema.

No hace falta publicar en App Store. Con un Personal Team gratuito tendrás que volver a firmar la app periódicamente. La validación real de background audio debe hacerse en un dispositivo; el simulador no reproduce fielmente el ciclo de vida de pantalla bloqueada.

## Capacidades Pi locales

`.pi/settings.json` activa únicamente en este proyecto:

- `pi-subagents`;
- `@upstash/context7-pi`;
- `@narumitw/pi-chrome-devtools`.

OpenSpec está instalado bajo `.pi/openspec`. Ejecuta `/reload` al abrir Pi desde este directorio para registrar herramientas, skills y comandos `/opsx:*`.
