# DiegoMusic

Ecosistema privado de música para **iOS, iPadOS, macOS, Android y Web**. Utiliza YouTube Data API v3 para explorar el catálogo musical y un backend propio FastAPI para resolver y entregar audio de alta fidelidad mediante sesiones opacas.

DiegoMusic no es una aplicación oficial ni está afiliada con YouTube o Google. Su uso respeta las condiciones del servicio y los derechos aplicables al contenido.

---

## Características principales

- **Ecosistema Multiplataforma Unificado**:
  - **iOS / iPadOS 17+ y macOS 14.8.5+**: App nativa Swift / SwiftUI con `AVPlayer`, Core Data, Now Playing y soporte completo para pantalla de bloqueo y Centro de control.
  - **Android**: App nativa en Kotlin con Jetpack Compose y ExoPlayer/Media3 (`diego-music-android`).
  - **Web**: Cliente web responsive en React 19, TypeScript, Vite y Tailwind CSS (`diego-music-web`), integrado en Docker Compose detrás de Traefik.
- **Letras sincronizadas en vivo (Live Lyrics)**:
  - Integración con la API pública de LRCLIB (`lrclib.net`), resaltado de línea activa en tiempo real, autoscroll, tap-to-seek y fondo glassmorphism con carátula difuminada.
  - **Normalización profunda de metadatos de YouTube**: Limpieza de sufijos de canales (`- Topic`, `VEVO` con división CamelCase `LadyGagaVEVO` → `Lady Gaga`, `Official`, `Music`), separación de colaboraciones y eliminación de etiquetas audiovisuales (`(Official Video)`, `(Video Oficial)`, `(Audio)`, `(Remastered ...)`, `[4K]`, `(feat. ...)`).
  - **Cascada tolerante de consulta (5 niveles)**: Búsqueda exacta por duración (`durationSeconds`), búsqueda limpia sin duración, búsqueda estructurada por campos, búsqueda de texto libre y fallback por título.
  - **Scoring y filtrado de candidatos**: Priorización de letras sincronizadas y validación por proximidad de duración (±3s a ±8s) para descartar pistas erróneas.
  - **Layout adaptativo**: Soporte para versos multilínea con anchura fijada a la ventana (`viewportWidth`) para evitar recortes horizontales en modo vertical.
  - **Botón minimalista de letras**: Acceso rápido en el reproductor minimizado (dock) y en la barra de herramientas y panel de acciones del reproductor expandido.
- **Autenticación y Sincronización en la Nube**:
  - Puerta de autenticación obligatoria (`AuthGate`) con registro seguro, hashing PBKDF2/bcrypt y tokens JWT.
  - Sincronización bidireccional en el backend de favoritos, playlists e historial de reproducción con SQLite WAL.
- **Búsqueda optimizada y gestión de cuota**:
  - Búsqueda bajo demanda, pool de claves con rotación automática (`KeyPool`) ante errores 403 (cuota) / 429, y deduplicación con caché local (`SearchCache`).
  - Endpoints alternativos en el VPS (`/v1/search` y `/v1/artist/{artist_id}`) impulsados por `yt-dlp` y caché LRU de artistas (`ArtistCache`) cuando se agota la cuota oficial.
- **Reproductor nativo y caché multicapa**:
  - Reproductor con estética Bauhaus Hi‑Fi y modo compacto/expandido.
  - Un único `AVPlayer` con play, pausa, seek, cola de reproducción y precarga silenciosa.
  - Caché de audio M4A persistente en el VPS (volumen Docker con límite global y expulsión LRU).
  - HTTPS automático mediante Traefik (proxy central del VPS).

---

## Plataformas y requisitos

| Componente | Requisito / Stack |
| --- | --- |
| **iPhone / iPad** | iOS/iPadOS 17 o posterior (Swift / SwiftUI) |
| **Mac** | macOS 14.8.5 o posterior (Swift / SwiftUI) |
| **Android** | Android 8.0+ (API 26+) — Kotlin, Jetpack Compose, Media3 |
| **Web** | Navegadores modernos (React 19, TypeScript, Vite) |
| **Backend & Resolver** | Python 3.12, FastAPI, SQLite WAL, `yt-dlp`, Docker Compose |
| **VPS / Infraestructura** | Traefik con TLS automático (Let's Encrypt), puertos 80/443 |
| **Catálogo** | Clave(s) de YouTube Data API v3 (admite lista separada por comas) |

El bundle ID de Apple es `com.diegocainzos.DiegoMusic`.

---

## Arquitectura del sistema

```text
                           CATÁLOGO Y AUTENTICACIÓN
DiegoMusic (iOS/Android/Web) ──> YouTube Data API v3 (KeyPool) ──> Búsqueda y catálogo
   │                               │
   │                               └── Fallback a VPS (/v1/search, /v1/artist)
   │
   └── Backend FastAPI (/api/auth, /api/users, /api/playlists) ──> SQLite WAL

                             SISTEMA DE LETRAS
DiegoMusic (iOS/Android/Web) ──> Normalización y limpieza de metadatos
   │
   └── Cascada tolerante 5 niveles ──> LRCLIB (lrclib.net) ──> Live Synced Lyrics

                               REPRODUCCIÓN
videoId ──> ResolverService (FastAPI) ──> yt-dlp ──> URL temporal upstream
   │               │
   │               ├── Sesión opaca firmada con expiración
   │               ├── Proxy HTTP HEAD/Range (206 Partial Content)
   │               └── Descarga y caché M4A persistente en disco
   │
   └──────── URL opaca temporal ────────> AVPlayer / ExoPlayer / Web Audio
```

La aplicación nunca recibe la URL upstream de Googlevideo ni sus cabeceras. El resolutor conserva esa información en memoria y solo entrega una URL opaca de vida limitada.

### Estructura de directorios

```text
DiegoMusic/                App nativa para iOS y macOS (Swift / SwiftUI)
  ├── App/                 Arranque, ciclo de vida y navegación
  ├── Core/                Modelos, networking, base de datos y preferencias
  ├── YouTube/             YouTube Data API, KeyPool, SearchCache y DTOs
  ├── Lyrics/              Cliente LRCLIB, extractor de metadatos, parser LRC y LyricsView
  ├── Features/Player/     PlayerDock, reproductor ampliado y gestión de cola
  └── Design/              Sistema de diseño Bauhaus Hi‑Fi

ResolverService/           Servicio resolutor de audio (FastAPI + yt-dlp)
  ├── app/                 Resolución de audio, streaming, caché M4A y sesiones
  └── tests/               Pruebas unitarias y de integración del resolutor

app/                       Backend API de usuario y catálogo (FastAPI + SQLite)
  └── routers/             Endpoints de autenticación, usuarios, playlists y catálogo

diego-music-android/       App nativa para Android (Kotlin, Jetpack Compose, Media3)
diego-music-web/           Cliente web (React 19, TypeScript, Vite, Tailwind CSS)
openspec/                  Especificaciones formales, diseño y tareas (OpenSpec)
```

---

## Caché multicapa

1. **Búsquedas locales (`SearchCache`)**: Actor en memoria con TTL de 24 horas y normalización de textos para deduplicar búsquedas idénticas sin consumir cuota de YouTube.
2. **Descriptores en el cliente**: Reutilización de sesiones activas, margen de seguridad y deduplicación de peticiones simultáneas.
3. **Resoluciones en el VPS**: Caché LRU `videoId → ResolvedAudio` (500 entradas, TTL máximo de 3 horas).
4. **Artistas en el VPS (`ArtistCache`)**: Caché LRU en FastAPI (`ARTIST_CACHE_MAX_ENTRIES=1000`, `TTL=86400s`) para perfiles y discografía.
5. **Audio M4A persistente**: Descarga en segundo plano mediante rangos, escritura atómica y expulsión LRU en el volumen `audio_cache` (hasta 5 GiB, máx. 256 MiB por pista).
6. **Precarga de cola**: Precarga silenciosa del siguiente tema y reintento automático transparente ante expiración.

---

## Configuración y Puesta en marcha

### 1. Variables de entorno locales

Crea `./.env` en la raíz del proyecto:

```dotenv
YOUTUBE_DATA_KEY=CLAVE_1,CLAVE_2
AUDIO_RESOLVER_BASE_URL=https://music.diegocainzos.cv
AUDIO_RESOLVER_API_TOKEN=TU_TOKEN_SECRETO_DE_AL_MENOS_32_CARACTERES
```

Genera el proyecto Xcode sin exponer secretos:

```bash
./scripts/generate-project.sh
```

### 2. Despliegue en VPS (Docker Compose)

En el servidor:

```bash
cd ResolverService
cp .env.example .env
# Configura RESOLVER_DOMAIN y DIEGOMUSIC_API_TOKEN en ResolverService/.env
```

Despliegue unificado con Traefik:

```bash
docker compose config --quiet
docker compose up -d --build
```

Comprobación del estado:

```bash
curl --fail https://music.diegocainzos.cv/health
```

---

## Descargas y Ejecución

- **iOS / macOS**: Abrir `DiegoMusic.xcodeproj` en Xcode 15+, configurar Team de firma y ejecutar con `⌘R`.
- **Android**:
  - Código fuente en `diego-music-android`.
  - Descarga directa de APK precompilada: [https://music.diegocainzos.cv/diegomusic.apk](https://music.diegocainzos.cv/diegomusic.apk)
- **Web**: Acceso directo en el navegador mediante el dominio configurado en Traefik.

---

## Validación y Pruebas

Comprobación de seguridad (sin filtrado de secretos):

```bash
./scripts/verify-no-secrets.py
```

Pruebas del resolutor y backend:

```bash
./scripts/validate-resolver.sh
```

Pruebas de la app Swift:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO test
```

Pruebas de Android:

```bash
cd diego-music-android && ./gradlew testDebugUnitTest
```

---

## Seguridad

- **Nunca versionar ni mostrar en logs valores de `.env`, `Secrets.xcconfig` ni tokens.**
- No registrar URLs completas de YouTube Data API (contienen la clave en el query string).
- No registrar Bearer tokens, tokens opacos de stream, cookies ni URLs de Googlevideo.
- Mantener Traefik como único punto de entrada público seguro con HTTPS.

Consulta [`AGENTS.md`](AGENTS.md) antes de realizar modificaciones automatizadas.
