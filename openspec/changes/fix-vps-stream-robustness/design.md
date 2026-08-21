# Design: Robustez de Streaming VPS y Resolución Automatizada

## Arquitectura y Flujo

1. **Resolución en `yt-dlp`**:
   - Se configuran los argumentos `--extractor-args "youtube:player_client=web_embedded,android,web"`.
   - `yt-dlp` utiliza el motor Deno preinstalado en la imagen para resolver los desafíos JavaScript y las firmas anti-bot de YouTube.
   - `/home/resolver/.cache` se monta como `tmpfs` para que la caché de funciones descifradas persista en memoria del contenedor sin colisionar con `read_only: true`.

2. **Caché en disco y Chunks**:
   - `_DOWNLOAD_CHUNK_BYTES` se fija en `1_048_576` (1MB) para no exceder los límites de fragmento impuestos por los balanceadores de Google CDN.
   - En `/v1/audio/stream/{token}`, si la pista está descargándose activamente en segundo plano, se espera hasta un tiempo máximo acotado (ej. 15s) para servir el archivo directamente con `FileResponse`, garantizando soporte de `Range` y `Seek` nativo en `AVPlayer`.

3. **Proxying y Peticiones HEAD**:
   - Al recibir `HEAD /v1/audio/stream/{token}`, el servidor comprueba el archivo en caché o realiza un sondeo upstream con `Range: bytes=0-0`, respondiendo a `AVPlayer` con las cabeceras requeridas (`Content-Type: audio/mp4`, `Accept-Ranges: bytes`, `Content-Length`) sin enviar un `HEAD` crudo al CDN de Google.
