# Capability: VPS Stream Robustness

## ADDED Requirements

### Requirement: Extractor Arguments en yt-dlp
`YTDLPResolver` MUST incluir `--extractor-args "youtube:player_client=web_embedded,android,web"` en las consultas y resolución de formatos.

#### Scenario: Resolución de audio con extractor configurado
- GIVEN un identificador de vídeo válido
- WHEN se invoca `resolve` o `search`
- THEN `yt-dlp` se ejecuta con el argumento de extractor adecuado.

### Requirement: Tamaño de fragmento de caché de 1MB
`PersistentAudioCache` MUST realizar descargas en bloques no superiores a 1MB (`1_048_576` bytes).

#### Scenario: Descarga de fragmentos a disco
- GIVEN una pista de audio upstream válida
- WHEN `PersistentAudioCache` descarga los fragmentos
- THEN el rango solicitado por cada bloque no excede 1.048.576 bytes.

### Requirement: Soporte de sondeo HEAD sin bloqueo upstream
`/v1/audio/stream/{token}` para peticiones `HEAD` MUST responder con cabeceras válidas sin emitir peticiones `HEAD` bloqueadas al CDN upstream.

#### Scenario: Inspección HEAD por AVPlayer
- GIVEN un token de sesión de audio válido
- WHEN el cliente realiza una petición `HEAD /v1/audio/stream/{token}`
- THEN el servidor responde con HTTP 200 y cabeceras `Content-Type` y `Accept-Ranges`.

### Requirement: Tmpfs para firmas en contenedor
El contenedor Docker de `ResolverService` MUST disponer de un punto de montaje `tmpfs` en `/home/resolver/.cache`.

#### Scenario: Almacenamiento de firmas de Deno
- GIVEN el contenedor ejecutándose en modo `read_only: true`
- WHEN `yt-dlp` resuelve un reto con Deno
- THEN la firma calculada se almacena en `/home/resolver/.cache` sin error de filesystem.
