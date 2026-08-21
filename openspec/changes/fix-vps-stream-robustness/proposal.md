## Why

Actualmente, las solicitudes de audio de AVPlayer en iOS fallan intermitentemente con el error `"AVPlayer no pudo abrir la pista entregada por el VPS"` (HTTP 502 Bad Gateway) debido a que los servidores de streaming de YouTube/Googlevideo rechazan peticiones directas de rangos grandes (>1MB), peticiones HTTP `HEAD` y peticiones sin el extractor adecuado en IPs de centro de datos. Además, la caché persistente intentaba descargar bloques de 4MB (rechazados con 403) y el contenedor de FastAPI no permitía a `yt-dlp` persistir las firmas resueltas por Deno en `/home/resolver/.cache` debido a `read_only: true`.

## What Changes

- **EXTRACTOR ROBUSTO EN YT-DLP**: Inclusión de `--extractor-args "youtube:player_client=web_embedded,android,web"` en las consultas y descargas de `yt-dlp` para resolver automáticamente firmas y PO Tokens con Deno sin requerir cookies manuales.
- **DESCARGA Y CACHÉ PERSISTENTE CON CHUNKS SEGUROS**: Ajuste del tamaño de chunk de descarga de `PersistentAudioCache` a 1MB (1.048.576 bytes) y soporte para esperar la finalización de la descarga en curso antes de responder al stream, garantizando que el audio se sirva de forma atómica y local desde disco (`FileResponse`).
- **SONDEO HEAD COMPATIBLE CON GOOGLEVIDEO**: Modificación de la inspección `HEAD` en `/v1/audio/stream/{token}` para usar sondeos ligeros `Range: bytes=0-0` hacia upstream en lugar de peticiones `HEAD` crudas que Googlevideo bloquea con 403.
- **TMPFS PARA FIRMAS DE YT-DLP/DENO**: Montaje de tmpfs en `/home/resolver/.cache` en `compose.yml` para que `yt-dlp` y Deno almacenen en caché las funciones JavaScript descifradas sin errores de sistema de ficheros de solo lectura.

## Capabilities

### New Capabilities
- `vps-stream-robustness`: Resolución automatizada de streams con Deno/yt-dlp, chunks de 1MB para descarga y compatibilidad total de sondeo con AVPlayer.

## Impact

- **FastAPI Resolver**: `ResolverService/app/resolver.py`, `ResolverService/app/audio_cache.py`, `ResolverService/app/main.py`.
- **Docker Compose**: `ResolverService/compose.yml`.
- **Tests**: `ResolverService/tests/test_resolver.py`, `ResolverService/tests/test_audio_cache.py`, `ResolverService/tests/test_api.py`.
