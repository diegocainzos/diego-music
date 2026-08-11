## Why

DiegoMusic reproduce una única pista con `AVPlayer`, publica metadatos en `MPNowPlayingInfoCenter` e integra la pantalla bloqueada y el centro de control; ahora la reproducción ampliada debería poder mostrar la letra sincronizada de la canción activa con desplazamiento automático. Sin embargo no existe ningún índice de letras local y no se debe scrapear letras con copyright. Este cambio añade una capability `lyrics` autocontenida: un proveedor opcional best‑effort con un contrato público (`LyricsView` + `LyricsProviding`) que otro cambio (`player-experience`, C1) podrá conectar al reproductor ampliado tras el merge, degradando con elegancia si no hay proveedor.

## What Changes

- Añadir una capability `lyrics` con ficheros nuevos bajo `DiegoMusic/Lyrics/`: un servicio de letras, modelos (`LyricsLine`/`LyricSegment`) y una vista con letras sincronizadas y auto‑scroll según el tiempo de reproducción.
- Definir un contrato público `LyricsProviding` que consume la pista activa (`MediaItem`) y el tiempo de reproducción, y expone `LyricsView` para su integración futura en el player ampliado por `player-experience`.
- Proveedor de letras **opcional y best‑effort**: el diseño no scrapes letras con copyright ni garantiza coincidencia; el default es local/no‑op con ejemplos embebidos marcados como experimentales.
- Degradación elegante: si no hay letra o proveedor, la vista muestra un estado vacío claro y no interrumpe la reproducción.
- Accesibilidad: VoiceOver anuncia la línea actual y se respeta `accessibilityReduceMotion`.

## Capabilities

### New Capabilities

- `lyrics`: vista de letras sincronizadas con auto‑scroll y proveedor `LyricsProviding` opcional/best‑effort, autocontenida bajo `DiegoMusic/Lyrics/` y ajena a la lógica de reproducción, cola, persistencia y capa de YouTube.

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ no existe aún). Esta capability es nueva y no modifica ninguna capability existente; la integración de `LyricsView` en el reproductor la hará `player-experience` (C1) tras el merge, sin tocar aquí la cola/AVPlayer. -->

## Impact

- Cliente: únicamente ficheros nuevos bajo `DiegoMusic/Lyrics/` (`LyricsService.swift`, `LyricsModels.swift`, `LyricsView.swift`). XcodeGen los incluye automáticamente al regenerar el proyecto; no se edita `project.yml`.
- Comportamiento: la app gana una vista de letras autocontenida y un seam público; sin proveedor, no cambia ningún flujo existente.
- Sin cambios en reproducción, resolución, cola, persistencia, capa de YouTube, `ResolverService` ni en ningún fichero de otro cambio (PlaybackQueue, AudioPlayerCoordinator, PlayerDock, LibraryStore, RootView, project.yml).
- La accesibilidad (labels, VoiceOver, reduce motion) se reafirma como requisito propio.