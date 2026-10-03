## ADDED Requirements

### Requirement: Superficie mínima de la API del backend
El backend MUST exponer bajo `/api/v1` únicamente las rutas de autenticación (`/auth/*`), playlists (`/playlists/*` salvo reordenación), favoritos (`/users/me/favorites*`) e historial (`/users/me/history`). Las rutas de catálogo, ajustes, estado del reproductor, seguimiento de artistas, telemetría y reordenación de playlists MUST NOT existir.

#### Scenario: Ruta de catálogo eliminada
- **WHEN** un cliente autenticado solicita `GET /api/v1/catalog/search?q=rock`
- **THEN** el servicio responde `404`.

#### Scenario: Rutas usadas por el cliente intactas
- **WHEN** un cliente autenticado crea una playlist, añade una pista por `youtube_video_id`, marca un favorito y registra historial
- **THEN** cada operación responde con éxito, igual que antes del cambio.

### Requirement: Sin telemetría de uso
El cliente iOS/macOS MUST NOT enviar eventos de uso o analítica a ningún servicio, y el backend MUST NOT almacenarlos.

#### Scenario: Inicio de sesión sin eventos
- **WHEN** un usuario inicia sesión, se registra, reproduce una pista o edita una playlist
- **THEN** el cliente no emite ninguna petición a `/api/v1/telemetry/*` ni a ningún otro destino de analítica.

### Requirement: Caché persistente con una única estrategia de descarga
`PersistentAudioCache` MUST descargar cada pista exclusivamente mediante `yt-dlp` sin shell y con timeout, escribir en un archivo temporal dentro del volumen de caché, descartar resultados vacíos o mayores que `min(AUDIO_CACHE_MAX_FILE_BYTES, AUDIO_CACHE_MAX_BYTES)` y publicar el archivo final mediante renombrado atómico. Nunca MUST servirse un archivo parcial.

#### Scenario: Descarga válida
- **WHEN** `yt-dlp` produce un archivo M4A no vacío dentro del límite por pista
- **THEN** la caché lo remuxa si es posible, lo renombra atómicamente a `<videoId>.m4a` y no deja archivos temporales.

#### Scenario: Descarga demasiado grande
- **WHEN** `yt-dlp` produce un archivo mayor que el límite por pista
- **THEN** la caché lo elimina, no publica `<videoId>.m4a` y la reproducción upstream continúa sin errores.

### Requirement: Una sola composición FastAPI y pruebas del backend en la validación
`ResolverService/app/main.py:create_app` MUST ser la única fábrica de la aplicación FastAPI desplegada, y `./scripts/validate-resolver.sh` MUST ejecutar también las pruebas de autenticación, playlists, favoritos e historial.

#### Scenario: Validación del resolutor
- **WHEN** se ejecuta `./scripts/validate-resolver.sh`
- **THEN** pytest ejecuta las pruebas del resolutor y del backend sobre la app construida con `create_app`.

### Requirement: Una sola definición de despliegue Compose
El repositorio MUST contener un único archivo Compose de despliegue, `compose.yml` en la raíz, con el resolver y el servicio web detrás de Traefik. La documentación y la validación MUST referenciar ese archivo.

#### Scenario: Validación de Compose
- **WHEN** se valida la configuración de despliegue
- **THEN** se ejecuta `docker compose --file compose.yml config --quiet` desde la raíz del repositorio y no existe `ResolverService/compose.yml`.
