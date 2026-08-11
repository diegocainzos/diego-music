## Context

DiegoMusic reproduce audio nativo con una única `AVPlayer` coordinada por `AudioPlayerCoordinator`, que publica título, artista, duración, posición y velocidad en `MPNowPlayingInfoCenter` y registra play/pause/siguiente/anterior/seek en `MPRemoteCommandCenter` (iOS). La pista activa se modela como `MediaItem` y el tiempo de reproducción expuesto como `currentTime`.

No existe índice de letras local. Obtener letras con derechos de autor requeriría scraping de fuentes ajenas, lo que queda explícitamente fuera de alcance. Por eso esta capability es **autocontenida y experimental**: define el contrato y una UI de letras sincronizadas, con un proveedor local por defecto y degradación elegante. No toca la cola, el `AudioPlayerCoordinator` ni la capa de YouTube, y no edita `project.yml`.

## Goals / Non-Goals

**Goals:**

- Añadir una vista de letras sincronizadas (`LyricsView`) con desplazamiento automático según `currentTime`.
- Definir el contrato público `LyricsProviding` que consume `MediaItem` + tiempo y que `player-experience` (C1) pueda conectar al reproductor ampliado tras el merge.
- Mantener la capability autocontenida bajo `DiegoMusic/Lyrics/` sin tocar ficheros de otros cambios.
- Proveer degradación elegante (estado vacío claro) cuando no haya letra o proveedor.
- Reafirmar accesibilidad: VoiceOver anuncia la línea actual y se respeta `accessibilityReduceMotion`.

**Non-Goals:**

- Scrapear letras con copyright ni garantizar coincidencia de letras reales.
- Editar `PlaybackQueue`, `AudioPlayerCoordinator`, `PlayerDock`, `LibraryStore`, `RootView`, `YouTubeDataService` ni `project.yml` (pertenecen a otros cambios).
- Integrar `LyricsView` en el player ampliado: esa integración la asume `player-experience` (C1) después del merge, consumiendo el seam público.
- Añadir dependencias externas de UI/letras.
- Garantizar un proveedor de letras en red en producción.

## Decisions

### Capability autocontenida bajo `DiegoMusic/Lyrics/`

Todos los ficheros nuevos residen en `DiegoMusic/Lyrics/` (`LyricsService.swift`, `LyricsModels.swift`, `LyricsView.swift`). Al ser ficheros nuevos, XcodeGen los incorpora al regenerar el proyecto con `./scripts/generate-project.sh`; no se edita `project.yml` en este cambio (eso lo hace exclusivamente el cambio CarPlay, C5).

Alternativa descartada: colocar la UI dentro de `PlayerDock.swift` o del coordinador. Eso invadiría ficheros de otro cambio y rompería el aislamiento de los worktrees paralelos.

### Contrato público `LyricsProviding`

Se define un protocolo `LyricsProviding` que, dada la pista activa (`MediaItem`) y el tiempo actual (en segundos), devuelve la letra sincronizada (líneas con `startTime`, `endTime` y `text`). `LyricsView` consume este proveedor y la corriente de tiempo de reproducción. `player-experience` (C1) lo inyectará en el player ampliado tras el merge; aquí solo se define el seam y un default local.

Alternativa descartada: acoplar directamente a `LyricsView`/`PlayerDock` con un suscriptor interno. Mantener `LyricsProviding` desacoplado permite a C1 integrarlo eligiendo el punto de inyección sin reescribir esta capability.

### Proveedor de letras opcional y best‑effort

El diseño no scrapea letras con copyright. El proveedor por defecto es **local/experimental**: puede devolver un conjunto de ejemplos embebidos claramente etiquetados o `nil`. El seam permite, en el futuro y con decisión explícita del usuario, sustituirlo por un proveedor de red legítimo. Si el proveedor devuelve `nil` o listas vacías, `LyricsView` muestra un estado vacío (“Letra no disponible”) sin interrumpir la reproducción.

### Auto‑scroll y reducción de movimiento

El desplazamiento automático se calcula a partir de `currentTime` y las marcas temporales de las líneas. Con `accessibilityReduceMotion` activado, el scroll pasa a saltar directamente a la línea activa sin animación de desplazamiento continuo.

## Risks / Trade-offs

- [Sin fuente real de letras] → proveedor local/experimental por defecto y degrado elegante; la capability no fabrica resultados falsos sobre letras con copyright.
- [Integración depende de otro cambio (C1)] → el seam público `LyricsProviding`/`LyricsView` queda fijado aquí; C1 solo inyecta. Si C1 no integra, la capability sigue autocontenida e inofensiva.
- [Auto‑scroll molesto o desincronizado] → scroll dirigido por marcas temporales + `accessibilityReduceMotion`; corrección a favor del contenido.
- [Ficheros nuevos no compilados en este host] → no hay Xcode aquí; la validación se limita al CLI de OpenSpec y a la regla de proyecto/sources, y el build real se fija en una Mac con `validate.sh`/`xcodebuild test`.

## Migration Plan

1. Añadir `LyricsModels.swift` (modelos `LyricsLine`/`LyricSegment`) y `LyricsService.swift` con el contrato `LyricsProviding` y el proveedor local/experimental por defecto.
2. Añadir `LyricsView.swift` con auto‑scroll, estado vacío y accesibilidad (VoiceOver lee la línea actual, respecta `accessibilityReduceMotion`).
3. Regenerar el proyecto (XcodeGen) si hay ficheros nuevos y ejecutar validaciones en una Mac; aquí solo se valida OpenSpec.
4. Dejar el seam público documentado para que `player-experience` (C1) lo integre en el player ampliado tras el merge.

Rollback: eliminar los ficheros bajo `DiegoMusic/Lyrics/`; nada más cambia en la app.

## Open Questions

- Verificar en dispositivo qué tan preciso resulta el auto‑scroll con marcas temporales reales una vez exista un proveedor legítimo.
- Decidir en el futuro si un proveedor de red obtiene licencia/permiso de letras; fuera de alcance aquí.
