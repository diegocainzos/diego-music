## 1. Proyecto

- [x] 1.1 `android/` con Gradle wrapper, catálogo de versiones y módulo `app` (Compose, Media3, Room, OkHttp, Coil, kotlinx.serialization)
- [x] 1.2 `BuildConfig` desde el `.env` raíz sin imprimir valores; `.gitignore` y `verify-no-secrets.py` actualizados
- [x] 1.3 `AndroidManifest`: `INTERNET`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `allowBackup=false` (la notificación de MediaSession no necesita `POST_NOTIFICATIONS`), `PlaybackService`

## 2. Núcleo

- [x] 2.1 Modelos (`MediaItem`, `PodcastShow`, `EpisodeProgressValue`…) y `PlaybackQueue` portada
- [x] 2.2 `AudioResolverClient` (validación, caché con margen, single‑flight, errores saneados)
- [x] 2.3 `YouTubeDataService` (endpoints, `KeyPool`, caídas al VPS, cachés, podcasts, radio, recomendaciones, búsqueda de canales)
- [x] 2.4 `AuthClient`, `BackendClient` y `TokenStore`
- [x] 2.5 Room + `LibraryStore` + `PlaybackSettings` (tema con migración, historial, continuar, velocidad)
- [x] 2.6 `OfflineDownloadManager` con escritura atómica y `NetworkMonitor`
- [x] 2.7 Letras: `TrackMetadataExtractor`, `LRCParser`, `LRCLibProvider`

## 3. Reproducción

- [x] 3.1 `PlayerCoordinator` (carga, precarga, reintento, repetir/aleatorio, radio, `warm`, episodios, persistencia de posición)
- [x] 3.2 `PlaybackService` + `ForwardingPlayer` (música: anterior/siguiente; episodio: −15/+30)
- [x] 3.3 `AppContainer` con sincronización completa y en tiempo real con el backend

## 4. Interfaz Donda

- [x] 4.1 Tema, tokens, tipografía y componentes base (carátula, chips, botones, toast, estado vacío)
- [x] 4.2 Raíz: puerta de autenticación, tres pestañas, mini‑player flotante, banner sin conexión, navegación con atrás
- [x] 4.3 Inicio, Buscar, Artista, Álbum
- [x] 4.4 Biblioteca (Playlists, Podcasts, Canciones, Álbumes, Artistas, Descargas) y Ajustes
- [x] 4.5 Detalle de podcast
- [x] 4.6 Reproductor expandido y letras

## 5. Verificación

- [x] 5.1 Tests JVM: cola, migración de tema, duración ISO 8601, normalización de búsqueda, extractor de metadatos, parser LRC, validación de `videoId`
- [x] 5.2 `./gradlew :app:testDebugUnitTest :app:assembleDebug` en verde
- [ ] 5.3 Capturas en emulador de Inicio, Buscar, Biblioteca y reproductor en negro y blanco (pendiente: sin espacio en disco para la imagen del emulador)
- [ ] 5.4 En un teléfono físico: pantalla bloqueada, auriculares, interrupciones y descarga
- [x] 5.5 `README.md` y `AGENTS.md` actualizados; `openspec validate android-donda-client --strict`
