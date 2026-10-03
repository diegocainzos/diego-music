## Why

La auditoría ponytail del 2026-10-03 encontró unas 2.000 líneas de código muerto, duplicado o especulativo repartidas entre el cliente Swift, el backend FastAPI y la infraestructura. También encontró riesgos de seguridad: una clave JWT por defecto escrita en el código, que `require_api_token` acepta desde be2b950; un administrador demo con contraseña fija sembrado en cualquier base vacía; y telemetría que envía correos y nombres, prohibida por AGENTS.md. Cada línea sobrante es superficie que hay que mantener, probar y proteger.

## What Changes

- **BREAKING (API)**: Eliminar endpoints que el cliente iOS/macOS no usa: `/api/v1/catalog/*`, `/api/v1/users/me/settings`, `/api/v1/users/me/player-state`, `/api/v1/users/me/following*`, `/api/v1/telemetry/events` y `PUT /api/v1/playlists/{id}/tracks/reorder`. También los modelos `UserSettings`, `UserPlayerState`, `UserFollow`, `UserDownload` y `UserActivityLog`, sus esquemas y el catálogo falso del seed.
- **BREAKING (operación)**: `SECRET_KEY` pasa a ser obligatoria (mínimo 32 caracteres) y ya no tiene valor por defecto. Sin ella el servicio no arranca. Si se genera una clave nueva, los JWT emitidos con la clave por defecto dejan de valer y los usuarios deben volver a iniciar sesión.
- El seed demo solo se ejecuta con `SEED_DEMO_DATA=true` y únicamente crea el usuario demo.
- Eliminar la telemetría de punta a punta (`TelemetryLogger`, sus llamadas y el router).
- Cliente Swift: un helper genérico `send` en `BackendAPIClient`; eliminar sobrecargas y DTOs sin uso, los protocolos con una sola implementación (`BackendAPIClientProtocol`, `AuthClientProtocol`, `TokenManaging`, `TelemetryLogging`), vistas, modificadores y helpers muertos, `LyricsService` y `LyricsProviding`, el autoplay `RelatedTrackProviding` que nunca se inyecta, `downloadBatch` y los casos de `DownloadError` que nunca se lanzan. Simplificar los fallbacks VPS de `YouTubeDataService`. Sustituir la LRU manual de `ArtworkCache` por `NSCache`.
- Resolver: conservar solo la descarga persistente vía `yt-dlp`, ahora con límite de tamaño por pista, y eliminar la copia por rangos con httpx. Deduplicar modelos y dicts de búsqueda y artista, recortar API de caché sin uso y eliminar el hack de `sys.path`.
- Backend: una sola composición FastAPI (`create_app`); se borra `app/main.py`, las pruebas raíz pasan a `ResolverService/tests` y `validate-resolver.sh` las ejecuta. Deduplicar comprobaciones de propiedad, resolución de pistas por `youtube_video_id` y construcción de favoritos.
- Infraestructura: conservar solo el `compose.yml` raíz, que es el desplegado detrás de Traefik junto al servicio web. Eliminar `ResolverService/compose.yml`, `ResolverService/Caddyfile`, el enlace `app_backend` y el `requirements.txt` raíz. La documentación usa `docker compose config --quiet`.
- Documentación: integrar en `openspec/` lo vigente de `specs/` y eliminar esa carpeta paralela.

## Capabilities

### New Capabilities
- `lean-service-surface`: Superficie mínima de API, sin telemetría, una sola composición FastAPI, un solo Compose y caché persistente con una única estrategia de descarga.
- `backend-secrets-hardening`: Clave JWT obligatoria sin valor por defecto, datos demo opcionales y documentación de Compose que no expande secretos.

### Modified Capabilities
- `user-activity-sync`: El estado del reproductor y el orden de pistas de las playlists dejan de sincronizarse con el backend (el cliente nunca lo hacía). Se conservan favoritos, playlists e historial.

## Impact

- **Swift**: `DiegoMusic/Core/Networking/*`, `DiegoMusic/App/*`, `DiegoMusic/AudioPlayer/*`, `DiegoMusic/Lyrics/*`, `DiegoMusic/Offline/*`, `DiegoMusic/YouTube/*`, `DiegoMusic/Design/*`, `DiegoMusic/Features/*`, `DiegoMusic/Core/Persistence/*` y `Tests/UnitTests/*`. Se eliminan archivos, así que hay que regenerar `DiegoMusic.xcodeproj` con `./scripts/generate-project.sh` en macOS.
- **Python**: `app/*`, `ResolverService/app/*`, `ResolverService/tests/*`; `tests/` raíz se elimina tras moverse.
- **Infra/Docs**: `compose.yml`, `ResolverService/Dockerfile`, `ResolverService/README.md`, `ResolverService/.env.example`, `README.md`, `AGENTS.md`, `scripts/validate-resolver.sh`, `specs/`.
- **Cliente web** (`../diego-music-web`): no estaba disponible durante la auditoría. Antes de desplegar, comprobar que no usa los endpoints eliminados.
- **Datos de producción**: si la base de producción ya contiene el usuario demo, eliminarlo o cambiar su contraseña manualmente. Este cambio no toca datos existentes.
