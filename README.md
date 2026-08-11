# DiegoMusic

Cliente privado de música para iPhone, iPad y Mac. Usa YouTube Data API v3 para explorar el catálogo y un resolutor propio para entregar audio a un reproductor nativo `AVPlayer`.

DiegoMusic no es una aplicación oficial ni está afiliada con YouTube o Google. Su uso debe respetar las condiciones del servicio y los derechos aplicables al contenido.

## Características

- **Letras sincronizadas en vivo (Live Lyrics)**: Integración con la API pública de LRCLIB (`lrclib.net`), resaltado de línea activa en tiempo real, autoscroll, toque para buscar (tap-to-seek), fondo con difuminado de carátula y diseño responsivo en orientación vertical.
- **Búsqueda optimizada y gestión de cuota**: Búsqueda bajo demanda en lugar de búsqueda en vivo al escribir, pool actorizado con rotación automática de claves de la API de YouTube en errores 403 (cuota) / 429, y deduplicación con caché local (`SearchCache`).
- **Servicios alternativos y caché en VPS**: Endpoints alternativos en el servidor (`/v1/search` y `/v1/artist/{artist_id}`) impulsados por `yt-dlp` y una caché LRU de artistas (`ArtistCache`) para continuar funcionando cuando la cuota de la API oficial se agote.
- **Vista de artista mejorada y navegación nativa**: Perfil completo de artista con verificado, éxitos populares numerados, discografía y artistas similares. Navegación fluida con botón de retorno (`chevron.left`) y acceso desde el reproductor minimizado/expandido.
- Reproductor compacto y ampliado con una estética Bauhaus digital y Hi‑Fi.
- Un único `AVPlayer` con play, pausa, seek, cola y avance automático.
- Reproducción en segundo plano y con la pantalla bloqueada en iOS.
- Integración con Centro de control, pantalla bloqueada y auriculares.
- Biblioteca local con favoritos, playlists e historial opcional mediante Core Data.
- Resolutor privado FastAPI + `yt-dlp`, protegido por Bearer token.
- HTTPS automático mediante Traefik (proxy central del VPS).
- Caché multicapa para acelerar repeticiones y precargar la siguiente pista.

## Plataformas y requisitos

| Componente | Requisito |
| --- | --- |
| iPhone/iPad | iOS/iPadOS 17 o posterior |
| Mac | macOS 14.8.5 o posterior |
| Desarrollo | Xcode 15 o posterior para SDK iOS 17 |
| Resolver | Docker Engine con Docker Compose v2 |
| VPS | Dominio público, puertos 80/443 y almacenamiento persistente |
| Catálogo | Clave(s) de YouTube Data API v3 (admite lista separada por comas) |

El bundle ID es `com.diegocainzos.DiegoMusic`. El destino mínimo es macOS 14.8.5; el proyecto usa Core Data de forma deliberada.

## Arquitectura

```text
                           CATÁLOGO
DiegoMusic ── YouTube Data API v3 (con KeyPool) ──> búsqueda y metadatos
   │
   └── Fallback a VPS (/v1/search, /v1/artist) ──> cuando la cuota se agota

                         REPRODUCCIÓN
videoId ──> ResolverService ──> yt-dlp ──> fuente temporal
   │               │
   │               ├── sesión opaca con expiración
   │               ├── proxy HTTP HEAD/Range
   │               └── caché M4A persistente
   │
   └──────── URL opaca temporal ────────> AVPlayer
```

La aplicación nunca recibe la URL upstream de Googlevideo ni sus cabeceras. El resolutor conserva esa información en memoria y solo entrega una URL opaca de vida limitada.

Directorios principales:

```text
DiegoMusic/App             Arranque, entorno y navegación
DiegoMusic/Core            Dominio, red, Core Data y preferencias
DiegoMusic/YouTube         YouTube Data API, KeyPool, SearchCache, DTOs y mapeo
DiegoMusic/Lyrics          Cliente LRCLIB, parser LRC y vista de letras Live Lyrics
DiegoMusic/AudioPlayer     AVPlayer, resolver, Now Playing y controles remotos
DiegoMusic/Design          Sistema visual Bauhaus Hi‑Fi
ResolverService/app        FastAPI, yt-dlp, sesiones, caché de audio y ArtistCache
ResolverService/tests      Pruebas del resolutor
Tests/UnitTests            Pruebas Swift
openspec/changes           Decisiones, especificaciones y tareas
```

## Caché multicapa

1. **Búsquedas locales (`SearchCache`)**: actor Swift en memoria con TTL de 24 horas y normalización de textos para deduplicar búsquedas identicas sin consumir cuota de la API de YouTube.
2. **Descriptores en DiegoMusic**: un actor Swift reutiliza sesiones vigentes, aplica margen de expiración y deduplica solicitudes simultáneas de streaming.
3. **Resoluciones en el VPS**: caché LRU `videoId → ResolvedAudio`, con 500 entradas y TTL máximo de 3 horas por defecto.
4. **Artistas en el VPS (`ArtistCache`)**: caché LRU en el servidor FastAPI (`ARTIST_CACHE_MAX_ENTRIES=1000`, `ARTIST_CACHE_TTL_SECONDS=86400`) para servir perfiles y éxitos populares desde el resolutor.
5. **Audio M4A persistente**: la primera reproducción descarga el archivo en segundo plano mediante rangos de 4 MiB, escritura atómica y expulsión LRU.
6. **Cola de reproducción**: DiegoMusic precarga silenciosamente la siguiente pista y reintenta una vez si una sesión desaparece.

Un token emitido durante el calentamiento cambia automáticamente a disco cuando el M4A está listo. El volumen Docker conserva hasta 5 GiB por defecto, con un máximo de 256 MiB por pista, y sobrevive a recreaciones de los contenedores.

## Configuración segura

Hay dos archivos locales diferentes y ambos están ignorados por Git:

### 1. Configuración de la aplicación

Crea `./.env` en la raíz:

```dotenv
YOUTUBE_DATA_KEY=CLAVE_1,CLAVE_2
AUDIO_RESOLVER_BASE_URL=https://audio.example.com
AUDIO_RESOLVER_API_TOKEN=REEMPLAZAR_CON_TOKEN_ALEATORIO
```

El generador transforma estas variables en `Config/Secrets.xcconfig` sin imprimir los valores:

```bash
./scripts/generate-project.sh
```

### 2. Configuración del resolutor

```bash
cd ResolverService
cp .env.example .env
```

Edita `ResolverService/.env` y configura como mínimo:

```dotenv
RESOLVER_DOMAIN=audio.example.com
DIEGOMUSIC_API_TOKEN=EL_MISMO_TOKEN_DE_LA_APLICACION
```

`AUDIO_RESOLVER_API_TOKEN` y `DIEGOMUSIC_API_TOKEN` deben contener exactamente el mismo valor. Usa un token aleatorio de al menos 32 caracteres y guárdalo en un gestor de contraseñas.

No ejecutes `docker compose config` sin filtrar su salida: puede expandir variables sensibles. Para validar la configuración sin mostrarla usa:

```bash
docker compose --file compose.yml config --quiet
```

## Puesta en marcha

### Resolver local o VPS

```bash
cd ResolverService
docker compose --file compose.yml config --quiet
docker compose --file compose.yml up --detach --build
docker compose --file compose.yml ps
```

Traefik (proxy central del VPS) expone únicamente 80/443 y enruta el tráfico hacia FastAPI, que permanece en el puerto 8080 interno dentro de la red Docker `proxy`. Comprueba el servicio:

```bash
curl --fail https://audio.example.com/health
```

Para un VPS real, configura antes el registro DNS del dominio hacia la IP pública. Traefik solicitará y renovará el certificado TLS automáticamente. El contenedor `resolver` debe unirse a la red externa `proxy` (etiquetas Traefik en `compose.yml`). Consulta [`ResolverService/README.md`](ResolverService/README.md) para despliegue, rotación de token, actualizaciones y operación de la caché.

### Aplicación

Desde la raíz del repositorio:

```bash
./scripts/generate-project.sh
open DiegoMusic.xcodeproj
```

`project.yml` es la fuente de verdad. El script instala XcodeGen 2.46.0 dentro de `.pi/tools` cuando no existe una instalación disponible y verifica su SHA-256.

En Xcode:

1. Selecciona el target `DiegoMusic`.
2. Abre **Signing & Capabilities**.
3. Mantén firma automática y selecciona tu Team.
4. Elige un Mac, simulador o dispositivo compatible.
5. Ejecuta con `⌘R`.

## Instalar en un iPhone

1. Usa una versión de Xcode compatible con la versión de iOS del teléfono.
2. Despliega primero el resolutor con HTTPS válido.
3. Conecta y desbloquea el iPhone y acepta la relación de confianza.
4. Activa **Ajustes → Privacidad y seguridad → Modo de desarrollador**.
5. Selecciona el dispositivo en Xcode y pulsa **Run**.
6. Prueba play/pause, seek, auriculares, pantalla bloqueada y Centro de control.

Con un Personal Team gratuito será necesario volver a firmar la aplicación periódicamente. La reproducción bloqueada debe validarse en hardware real; el simulador no reproduce fielmente ese ciclo de vida.

## Validación

Validación completa:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/validate.sh
```

Comprobaciones individuales:

```bash
./scripts/verify-no-secrets.py
./scripts/validate-resolver.sh

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Las pruebas Python sustituyen `yt-dlp` y Googlevideo por dobles locales. No necesitan credenciales ni exponen URLs firmadas.

## Operación del resolutor

Estado y logs sanitizados:

```bash
cd ResolverService
docker compose --file compose.yml ps
docker compose --file compose.yml logs --tail 100 resolver
```

Uso del volumen de audio:

```bash
docker compose --file compose.yml exec resolver \
  du -sh /var/cache/diegomusic
```

Actualizar la imagen y `yt-dlp`:

```bash
docker compose --file compose.yml build --pull --no-cache resolver
docker compose --file compose.yml up --detach
```

`docker compose down` conserva los volúmenes. No uses `down --volumes` salvo que quieras eliminar también la caché M4A.

## Seguridad

- No versionar ni mostrar `.env`, `ResolverService/.env` o `Config/Secrets.xcconfig`.
- No registrar URLs de YouTube Data API completas: contienen la clave como query parameter.
- No registrar Bearer tokens, tokens opacos de stream, cookies, PO tokens ni URLs multimedia firmadas.
- No exponer directamente el puerto 8080 ni convertir el resolutor en un proxy de URLs arbitrarias.
- Mantener desactivados los access logs de Traefik o redactar `/v1/audio/stream/*` antes de habilitarlos.
- Proteger el volumen `audio_cache`: contiene archivos de audio completos.
- Restringir la clave de Google Cloud a YouTube Data API v3 y aplicar límites de cuota.

Consulta [`AGENTS.md`](AGENTS.md) antes de realizar cambios automatizados en el repositorio.

## Herramientas del proyecto

Las capacidades Pi, OpenSpec, XcodeGen y demás herramientas están instaladas localmente bajo `.pi`; no requieren ni deben crear instalaciones globales. Después de sincronizar cambios de configuración Pi, reinicia Pi o ejecuta `/reload` desde este directorio.
