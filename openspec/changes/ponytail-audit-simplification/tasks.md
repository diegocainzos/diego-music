# Tasks: Simplificación tras auditoría ponytail

Las tareas se reparten en paquetes con propiedad de archivos disjunta para poder ejecutarse en paralelo. Cada paquete solo edita los archivos de su lista.

## 1. Paquete A: Python, infraestructura y documentación operativa

Propiedad: `app/**`, `tests/**` (raíz), `ResolverService/**`, `compose.yml`, `requirements.txt` (raíz), `app_backend`, `backend_app`, `scripts/validate-resolver.sh`, `README.md`, `AGENTS.md`.

- [x] 1.1 Eliminar `app/routers/catalog.py`, su `include_router` y el catálogo del seed (artistas, álbumes y pistas de ejemplo) <!-- id: a-catalog -->
- [x] 1.2 Eliminar los endpoints `/users/me/settings`, `/users/me/player-state` y `/users/me/following*`, los modelos `UserSettings`, `UserPlayerState`, `UserFollow` y `UserDownload`, sus relaciones en `User`/`Artist`, sus esquemas y las inicializaciones en `register` y el seed <!-- id: a-user-state -->
- [x] 1.3 Eliminar el router `telemetry`, el modelo `UserActivityLog` y los esquemas `TelemetryEvent*` <!-- id: a-telemetry -->
- [x] 1.4 Eliminar `PUT /playlists/{id}/tracks/reorder` y `PlaylistTrackReorder` <!-- id: a-reorder -->
- [x] 1.5 Deduplicar el backend: helper `_owned_playlist()` para las 5 comprobaciones 404/403, un helper para resolver `track_id`/`youtube_video_id` con un mixin de esquema para los 6 campos de metadatos de YouTube, y un helper para construir `FavoriteResponse`. Eliminar la comprobación de longitud repetida en `validate_password_complexity` (se conserva la de mayúscula) y `TokenData` <!-- id: a-backend-shrink -->
- [x] 1.6 `app/config.py`: `SECRET_KEY` obligatoria (≥32 caracteres), sin valor por defecto ni `os.getenv` dentro de `BaseSettings`; error `ConfigurationError` saneado. Eliminar `PROJECT_NAME`/`VERSION` si quedan sin uso. Añadir `SECRET_KEY=` y `SEED_DEMO_DATA=false` a `ResolverService/.env.example` <!-- id: a-secret-key -->
- [x] 1.7 Ejecutar el seed demo (solo usuario) únicamente con `SEED_DEMO_DATA` en `true`/`1`/`yes` <!-- id: a-seed-optin -->
- [x] 1.8 Eliminar `app/main.py`; mover `tests/test_backend_auth.py` y `tests/test_playlists_activity.py` a `ResolverService/tests/` usando `create_app(Settings(...))`, `backend_app.*`, base SQLite temporal en `tmp_path` y `SECRET_KEY` ficticia en `conftest.py`; adaptar o borrar las pruebas de endpoints eliminados; añadir una prueba que rechace un JWT firmado con otra clave. Eliminar `tests/` raíz y `requirements.txt` raíz <!-- id: a-single-app -->
- [x] 1.9 `ResolverService/pytest.ini` con `pythonpath = . ..`; eliminar el `sys.path.insert` de `ResolverService/app/main.py`; eliminar el enlace `app_backend` <!-- id: a-pythonpath -->
- [x] 1.10 `audio_cache.py`: conservar solo la ruta `yt-dlp` y eliminar la copia httpx por rangos, `_content_length`, `_CONTENT_RANGE`, `_DOWNLOAD_CHUNK_BYTES` y `anyio`. `schedule(video_id)` sin `audio`/`client`; validar tamaño >0 y ≤ `min(max_file_bytes, max_bytes)`. Actualizar llamadas en `main.py` y reescribir `test_audio_cache.py` con un `yt-dlp` falso (script en `tmp_path`). Eliminar `total_bytes` <!-- id: a-audio-cache -->
- [x] 1.11 Resolver: unificar `ArtistTrackItem` con `SearchResultItem`; `search_fallback` devuelve `SearchResponse(items=raw_results)`; `get_artist_detail` sin las copias de dicts ni el alias `artist_name`; importar `Any`; corregir `str(str(...))`; eliminar `ResolvedAudio.is_cached_file` (usar `cached_path is not None`); eliminar `invalidate`, `clear`, `entry_count` y `_remove_expired` sin uso de `ArtistCache`/`CachingAudioResolver`; compartir el filtrado de cabeceras entre las ramas GET y HEAD de `proxy_audio` <!-- id: a-resolver-shrink -->
- [x] 1.12 Conservar el `compose.yml` raíz; eliminar `ResolverService/compose.yml` y `ResolverService/Caddyfile`. Actualizar `ResolverService/README.md`, `README.md` y `AGENTS.md` para usar `docker compose --file compose.yml ... ` desde la raíz y siempre `config --quiet` <!-- id: a-compose -->
- [x] 1.13 Ejecutar `./scripts/verify-no-secrets.py`, `./scripts/validate-resolver.sh` y `docker compose --file compose.yml config --quiet` (desde la raíz, sin mostrar salida) <!-- id: a-validate -->
  - 102 pruebas pasan. `config --quiet` falla en local solo porque faltan `ResolverService/.env` y `../diego-music-web`; con un `.env` de marcador en una copia temporal, el archivo valida.

## 2. Paquete B: red Swift, autenticación y documentación heredada

Propiedad: `DiegoMusic/Core/Networking/**`, `DiegoMusic/App/AppEnvironment.swift`, `Tests/UnitTests/BackendAPIClientTests.swift`, `Tests/UnitTests/AuthClientTests.swift`, `specs/**`.

- [x] 2.1 `BackendAPIClient`: helper privado genérico `send` (método, ruta, token, cuerpo opcional, decodificación opcional) que sustituye el bloque repetido de petición, cabecera Bearer, estado y decodificación <!-- id: b-send-helper -->
- [x] 2.2 Eliminar métodos sin uso: catálogo (`searchCatalog`, `fetchArtists`, `fetchAlbums`, `fetchTracks`), `fetchUserSettings`, `fetchPlayerState`, `updatePlayerState`, `updatePlaylist`, `reorderPlaylistTracks` y las sobrecargas `trackID:`/`entityID:` de `addTrackToPlaylist`, `addFavorite`, `removeFavorite`, `removeTrackFromPlaylist` y `recordPlayHistory` <!-- id: b-unused-methods -->
- [x] 2.3 Eliminar los DTOs y payloads que queden sin uso en `BackendModels.swift` (catálogo, ajustes, estado del reproductor, reordenación, `BackendPlaylistTrackDTO` si procede) <!-- id: b-unused-dtos -->
- [x] 2.4 Eliminar `BackendAPIClientProtocol`, `AuthClientProtocol` y `TokenManaging`; `AppEnvironment` usa los tipos concretos <!-- id: b-protocols -->
- [x] 2.5 Eliminar `TelemetryLogger.swift` (con `TelemetryLogging`) y sus llamadas en `AppEnvironment` <!-- id: b-telemetry -->
- [x] 2.6 Eliminar `AuthState.currentUser` <!-- id: b-auth-state -->
- [x] 2.7 Actualizar `BackendAPIClientTests` y `AuthClientTests` (sin pruebas de métodos eliminados) <!-- id: b-tests -->
- [x] 2.8 `specs/`: asociar cada documento a su cambio en `openspec/changes/`, eliminar la carpeta y registrar la correspondencia en esta tarea <!-- id: b-legacy-specs -->
  - Mapping: `01_backend_auth_spec` → `enforce-mandatory-auth-and-sync`, `add-swift-backend-auth`, `home-playlists-activity`; `01_theme_logo`, `02_home`, `03_artist_page`, `04_playlist_player_navigation`, `05_qa` → `apple-music-overhaul`; `home_spec`, `layout_navigation_spec`, `theme_spec`, `qa_test_spec` → `apple-music-ui-fixes`; `lyrics_01..03` → `lyrics`, `improve-lyrics-accuracy`.
  - Se conservan `specs/offline_01..04_*.md`: ningún cambio OpenSpec cubre las descargas offline. Eliminarlos cuando exista un cambio `offline-downloads`.

## 3. Paquete C: código Swift muerto y simplificaciones de funcionalidades

Propiedad: el resto de `DiegoMusic/**` (incluido `DiegoMusic/Features/Playlists/PlaylistsView.swift`) y el resto de `Tests/UnitTests/**`.

- [x] 3.1 Eliminar código muerto: `LibraryTrackRow.swift`, `NavigationHeaderView`, `LibraryStore.recommendations`, `LibraryStore.deleteFavorite`, `appleMusicCard`, `glassCard`, `AppleMusicCardModifier`, `YouTubeAPIErrorEnvelopeDTO`, `DownloadProgressEvent`, `RootView.themed`, `DiegoAppDestination.accentColor`, el typealias `AppDestination` (usar `DiegoAppDestination`), `PlaybackSettings.clearRestoreState`, `queueAnimationNamespace`, `DiegoTheme.textTertiary` y `DiegoTheme.glassMaterial` <!-- id: c-dead-code -->
- [x] 3.2 Eliminar `AudioPlayerCoordinator.resolverClient` (usar `resolver`) y actualizar `RootView`, `AlbumView` y `PlaylistsView` <!-- id: c-resolver-client -->
- [x] 3.3 Eliminar las llamadas a `TelemetryLogger` en `PlaylistsView` <!-- id: c-telemetry-calls -->
- [x] 3.4 Eliminar `RelatedTrackProviding`, `relatedProvider`, `handleQueueEnded` y `enqueueAndPlayRelated` (la cola terminada con repetición desactivada se detiene) <!-- id: c-autoplay -->
- [x] 3.5 Eliminar `LyricsService` y `LyricsProviding`; `PlayerDock` y `LyricsView` usan `LRCLibLyricsProvider.fetchLyrics(for:)`; eliminar `LRCLibLyricsProvider.lyrics(for:at:)` <!-- id: c-lyrics -->
- [x] 3.6 Offline: eliminar `downloadBatch` (`OfflineViews` usa `enqueueBatch`), los casos de `DownloadError` que nunca se lanzan (`alreadyDownloaded`, `writeFailed`, `quotaExceeded`, `unknown`), las ramas mp3/ogg/webm de `extensionFor` y `availableDiskSpaceBytes` <!-- id: c-offline -->
- [x] 3.7 `YouTubeDataService`: un helper GET para el VPS, un DTO de pista compartido y un mapeo a `MediaItem`; deduplicar `fetchRelatedRadio` con un `Set` insertado; eliminar `case 500...599`, que repite `default`; simplificar la rama de una sola clave en `executeWithRotation`; eliminar la extensión de valores por defecto de `YouTubeDataServicing` (completar `UnavailableDiscoveryService`) y la de `AudioStreamResolving.invalidate` <!-- id: c-youtube -->
- [x] 3.8 `ArtworkCache`: sustituir la LRU manual por `NSCache` con `countLimit = 32` <!-- id: c-artwork -->
- [x] 3.9 Eliminar `AudioResolverClient.cacheEntryCount` y adaptar `AudioResolverClientTests` para afirmar la deduplicación por número de peticiones; adaptar `OfflineDownloadManagerTests` <!-- id: c-test-accessors -->

## 4. Validación final (coordinador)

- [x] 4.1 `.pi/openspec/node_modules/.bin/openspec validate ponytail-audit-simplification --type change --strict` <!-- id: v-openspec -->
- [x] 4.2 Búsqueda global de referencias a símbolos eliminados en Swift y Python <!-- id: v-references -->
- [x] 4.3 `./scripts/verify-no-secrets.py`, `./scripts/validate-resolver.sh`, `git diff --check` y `git status` <!-- id: v-checks -->

## 5. Pendiente en macOS (manual)

- [ ] 5.1 `./scripts/generate-project.sh` para regenerar `DiegoMusic.xcodeproj` (se eliminaron archivos Swift) <!-- id: m-xcodegen -->
- [ ] 5.2 `xcodebuild ... -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test` <!-- id: m-macos-test -->
- [ ] 5.3 `xcodebuild ... -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing` <!-- id: m-ios-build -->

## 6. Antes de desplegar (manual)

- [ ] 6.1 Añadir `SECRET_KEY` (≥32 caracteres aleatorios) a `ResolverService/.env` en el VPS <!-- id: d-secret -->
- [ ] 6.2 Confirmar que `../diego-music-web` no usa los endpoints eliminados <!-- id: d-web-client -->
- [ ] 6.3 Eliminar o cambiar la contraseña del usuario demo si existe en la base de producción <!-- id: d-demo-user -->
