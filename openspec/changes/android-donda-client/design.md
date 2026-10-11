# Diseño: cliente Android Donda

Referencia funcional: el código Swift de `DiegoMusic/` en `main` (commit `28908ce`). Referencia visual: `openspec/changes/donda-ui-podcasts-radio/` y su mockup.

## Context

- La app Swift ya fija el comportamiento: `AudioPlayerCoordinator` (un único `AVPlayer` con una pista cargada cada vez y la cola gestionada por `PlaybackQueue`), `YouTubeDataService` con `KeyPool`, `AudioResolverClient` con caché y *single‑flight*, `LibraryStore` sobre Core Data y la sincronización con el backend en `AppEnvironment`.
- El backend acepta el token estático del resolutor y también el JWT del usuario. Para no cambiar nada, Android usa lo mismo que Swift: el token estático para `/v1/*` y el JWT para `/api/v1/*`.

## Decisions

### 1. Stack mínimo

| Necesidad | Elección | Motivo |
|---|---|---|
| UI | Jetpack Compose + Material3 con formas rectangulares | Material3 solo aporta Slider, menús y hojas; el aspecto lo definen los tokens Donda |
| Reproducción | Media3 ExoPlayer + `MediaSessionService` | Segundo plano, notificación, pantalla de bloqueo y auriculares sin código propio |
| Persistencia | Room (KSP) | Equivalente directo de Core Data con consultas tipadas |
| Red | OkHttp + kotlinx.serialization | Coil ya trae OkHttp; la serialización se resuelve al compilar |
| Imágenes | Coil 3 | Compose no tiene cargador de imágenes propio |
| Inyección | `AppContainer` manual en `Application` | Un único grafo; Hilt no compensa |
| Navegación | Pila propia (`NavigationState`), portada de Swift | Misma semántica de pestañas y atrás; `BackHandler` para el botón del sistema |

Versiones fijadas en `gradle/libs.versions.toml`. `minSdk` 26 (Android 8), `targetSdk`/`compileSdk` 35, JDK 17.

### 2. Un único reproductor, una pista cargada

`PlayerCoordinator` es el equivalente de `AudioPlayerCoordinator`: posee el único `ExoPlayer`, carga una sola `MediaItem` cada vez y delega la cola en `PlaybackQueue` (portada línea a línea). Así se conservan la precarga, el reintento único, `warm`, la radio que sustituye solo lo posterior a la pista actual y el progreso por episodio.

`PlaybackService : MediaSessionService` publica una `MediaSession` sobre un `ForwardingPlayer` que envuelve ese `ExoPlayer`:

- con música anuncia `COMMAND_SEEK_TO_NEXT` y `COMMAND_SEEK_TO_PREVIOUS`, y los redirige a `coordinator.next()` y `previous()`;
- con un episodio los oculta y anuncia `seekBack` (15 s) y `seekForward` (30 s), equivalentes a `skipBackwardCommand` y `skipForwardCommand`.

`MainActivity` conecta un `MediaController` al arrancar para que el servicio exista; Media3 lo pasa a primer plano mientras suena.

### 3. Resolutor, catálogo y backend

- `AudioResolverClient`: valida el `videoId` (11 caracteres `[A-Za-z0-9_-]`), cachea descriptores hasta `expiresAt − 90 s`, agrupa peticiones simultáneas con un `Deferred` por `videoId`, exige `https`, `audio/*` y expiración futura, y sanea los mensajes de error 422 igual que Swift.
- `YouTubeDataService`: mismos endpoints, parámetros, mapeos, catálogo de reserva, caché de búsqueda de 24 h con normalización, caché de episodios de 1 h y rotación de claves ante 403 de cuota o 429. Cualquier fallo del VPS se traduce en `quotaExceeded`, como en Swift.
- Búsqueda: además de `type=video` (`videoCategoryId=10`), se lanza en paralelo `type=channel` con `maxResults=3`. Los canales aparecen primero con el botón «SEGUIR». *Coste*: 100 unidades más por búsqueda nueva; la caché de 24 h lo amortigua. *Alternativa descartada*: `type=video,channel` en una sola llamada, porque obliga a quitar `videoCategoryId=10` y empeora los resultados musicales.
- `BackendClient`: los mismos endpoints `/api/v1/*`, formulario `x-www-form-urlencoded` para el login y JSON para el resto. La sincronización completa y los ganchos en tiempo real de `LibraryStore` replican `AppEnvironment`.

### 4. Persistencia

Room replica las entidades de Core Data: `FavoriteTrack`, `Playlist`, `PlaylistEntry`, `PlaybackHistory`, `Preference`, `SavedAlbum`, `DownloadedTrack`, `FollowedShow` y `EpisodeProgress`, con las mismas claves únicas. `LibraryStore` expone `StateFlow` para la UI. Las preferencias (tema, historial, continuar, velocidad, búsquedas recientes, siembra de podcasts) van en `Preference` con las mismas claves que Swift.

El JWT se guarda en `SharedPreferences` privadas; el respaldo está desactivado (`allowBackup=false`). *Alternativa descartada*: `EncryptedSharedPreferences`, porque la biblioteca está obsoleta y el almacén privado de la app ya está aislado.

### 5. Descargas

`OfflineDownloadManager` mantiene la misma cola secuencial con 2 reintentos, pero escribe en streaming a `files/Downloads/<id>.m4a.part` y renombra al terminar, en lugar de acumular el audio en memoria como Swift. El progreso se publica por `videoId`.

### 6. Donda en Compose

- Tokens en `DondaColors` (negro/blanco), servidos con `CompositionLocal` y elegidos por `AppThemeMode` con la misma migración (`light`/`white` → blanco; lo demás → negro). Las barras del sistema siguen al tema.
- `dondaLabel`: `FontFamily.Monospace`, 11 sp, mayúsculas, `letterSpacing` 1,4 sp. `dondaTitle(size)`: `sans-serif-condensed` regular, mayúsculas, 2,4 sp. No se empaquetan fuentes.
- Radio 0 en todo (`MaterialTheme.shapes` rectangulares), bordes de 1 dp, estado activo invertido. La única sombra es la del mini‑player.
- Los SF Symbols se sustituyen por sus equivalentes de Material Icons (`chevron.down` → `KeyboardArrowDown`, `quote.bubble` → `FormatQuote`, `goforward.30` → `Forward30`, etc.).
- Medidas en dp iguales a los pt de Swift (mini‑player 42 dp de carátula, botón de play de 72 dp, márgenes de 16 dp, tarjetas de 128 dp…).
- Letras: la columna de líneas se fija al ancho visible (invariante `viewportWidth` de `LyricsView`).

### 7. Credenciales

`app/build.gradle.kts` lee `YOUTUBE_DATA_KEY`, `AUDIO_RESOLVER_BASE_URL` y `AUDIO_RESOLVER_API_TOKEN` del `.env` raíz (o de variables de entorno) y los inyecta en `BuildConfig`. Gradle no imprime esos valores. Igual que en iOS, quedan dentro del binario: el APK es de uso privado y no se distribuye.

## Risks / Trade-offs

- **El token estático va dentro del APK**, como en el `.ipa`. Si el APK se filtra, hay que rotar el token. Usar el JWT para `/v1/*` lo evitaría, pero cambia el comportamiento respecto a Swift; queda como mejora posterior.
- **Cuota de búsqueda**: la búsqueda de canales duplica el coste de cada búsqueda nueva.
- **Descargas en segundo plano**: si el sistema mata el proceso, la cola se pierde y los `.part` se borran en el siguiente arranque.
- **Pantalla bloqueada, auriculares e interrupciones** dependen de Media3. Se verifican en un dispositivo físico.

## Migration Plan

No hay datos previos en Android. El backend sincroniza favoritos, playlists e historial al iniciar sesión. Los podcasts seguidos y su progreso son locales del dispositivo, como en iOS, y se siembran JRE y The Wild Project.
