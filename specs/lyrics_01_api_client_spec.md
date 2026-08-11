# Lyrics 01 — LRCLIB API Client & LRC Parser

## Objetivo

Implementar un cliente Swift nativo para la API pública de **LRCLIB** (`https://lrclib.net`) que obtenga letras sincronizadas y planas para la pista activa, con un parser LRC robusto y caché en memoria.

## API LRCLIB

### Endpoint principal: `GET /api/get`

```
GET https://lrclib.net/api/get?artist_name={artist}&track_name={track}&album_name={album}&duration={seconds}
```

**Cabecera obligatoria:**
```
User-Agent: AppleMusicClone/1.0 (https://github.com/app)
```

**Respuesta exitosa (200):**
```json
{
  "id": 16233,
  "trackName": "Yellow",
  "artistName": "Coldplay",
  "albumName": "Parachutes",
  "duration": 267,
  "instrumental": false,
  "plainLyrics": "Look at the stars\nLook how they shine for you...",
  "syncedLyrics": "[00:33.80] Look at the stars\n[00:36.23] Look how they shine for you\n..."
}
```

Si devuelve **404**, se usa el fallback.

### Endpoint fallback: `GET /api/search`

```
GET https://lrclib.net/api/search?q={artist}+{track}
```

Devuelve un array de resultados. Seleccionar el primer resultado que tenga `syncedLyrics` no nulo; si ninguno tiene synced, usar el primero con `plainLyrics`.

## Parser LRC

La función `parseLRC(_ lrcString: String) -> [LyricsLine]`:

1. Divide el string por líneas (`\n`).
2. Para cada línea, extrae timestamps con regex: `\[(\d{2}):(\d{2})\.(\d{2,3})\]`.
3. Convierte a segundos flotantes: `minutes * 60 + seconds + centiseconds / 100`.
4. Retorna `[LyricsLine]` ordenado por `startTime`.
5. Calcula `endTime` como el `startTime` de la siguiente línea (o `nil` para la última).
6. Filtra líneas vacías opcionalmente (líneas con solo whitespace se mantienen como separadores instrumentales).

### Ejemplo de conversión

```
[01:23.45] Texto de la letra  →  LyricsLine(text: "Texto de la letra", startTime: 83.45, endTime: ...)
[01:23.456] Con milisegundos   →  LyricsLine(text: "Con milisegundos", startTime: 83.456, endTime: ...)
```

## Modelo de datos

Reutilizar los modelos existentes en `LyricsModels.swift`:
- `LyricsLine(text:startTime:endTime:)` — ya existe.
- `LyricSegment(lines:)` — ya existe.

Añadir modelo de respuesta API:
```swift
struct LRCLibResponse: Codable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Int
    let instrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?
}
```

## Caché en memoria

- Diccionario `[String: LyricsResult]` indexado por `videoId` (que es `MediaItem.id`).
- `LyricsResult` es un enum: `.synced([LyricSegment])`, `.plain(String)`, `.notFound`, `.instrumental`.
- TTL de 30 minutos (las letras no cambian, pero evita crecimiento ilimitado).
- Thread-safe vía actor isolation.

## Estrategia de fallback

1. **Caché hit** → devolver inmediatamente.
2. **`/api/get`** con `artist_name`, `track_name`, `duration` → si tiene `syncedLyrics`, parsear LRC.
3. Si `syncedLyrics` es nil pero `plainLyrics` existe → devolver `.plain`.
4. Si `instrumental == true` → devolver `.instrumental`.
5. Si 404 → intentar **`/api/search`** con query `"{artist} {track}"`.
6. Si search tampoco devuelve resultados → `.notFound`.

## Extracción de artista/título desde MediaItem

`MediaItem` tiene `title` (que puede ser "Coldplay - Yellow" o "Yellow (Official Video)") y `channelTitle` (que suele ser el nombre del artista). El servicio debe:
1. Usar `channelTitle` como `artist_name`.
2. Limpiar `title` eliminando sufijos comunes: `(Official Video)`, `(Official Music Video)`, `(Lyrics)`, `(Audio)`, `[Official Video]`, etc.
3. Si `title` contiene " - ", separar en artista y título de pista.

## Conformidad con LyricsProviding

Implementar `LRCLibLyricsProvider: LyricsProviding` que sustituya a `LocalLyricsProvider` como provider por defecto en `LyricsService`.

## Restricciones

- No cachear secretos ni URLs upstream.
- No contactar YouTube ni Googlevideo; LRCLIB es un servicio externo independiente.
- Errores de red degradan silenciosamente a "Letra no disponible".
- Timeout de 10 segundos para cada petición HTTP.
