## Context

DiegoMusic reproduce audio con una única `AVPlayer` coordinada por `AudioPlayerCoordinator` (@MainActor, `ObservableObject`), que ya gestiona cola (`PlaybackQueue`), play/pause/siguiente/anterior/seek, precarga de la siguiente pista, Now Playing + carátula y comandos remotos. `PlaybackQueue` ofrece `advance()`/`retreat()`/`move()`/`play(_:)` y `clear()`; `PlayerDock` tiene dos estados (compacto/ampliado) con editor de cola; `PlaybackSettings` persiste preferencias vía `LibraryStore.setPreference`; `AppEnvironment` reúne los servicios y orquesta `play(_:)`.

Hoy no existe: shuffle, repeat, persistencia de la reproducción al reabrir, reordenación por arrastre, gesto de swipe para siguiente/anterior, arrastre hacia abajo para cerrar, ni autoplay/radio.

## Goals / Non-Goals

**Goals:**

- Añadir modos shuffle y repeat (pista / lista / off) conmutables desde el reproductor, preservando la pista activa.
- Hacer la cola reordenable por arrastre ("toca para poner después") además de las flechas existentes.
- Restaurar la pista activa y su `currentTime` al reabrir la app, respetando ajustes.
- Añadir gestos: deslizar para siguiente/anterior y arrastrar hacia abajo para cerrar el ampliado, con áreas táctiles y etiquetas accesibles.
- Encadenar música relacionada al terminar la cola mediante un proveedor inyectado (`RelatedTrackProviding`), best‑effort.
- Mantener un único `AVPlayer`, audio en segundo plano, Now Playing y accesibilidad.

**Non-Goals:**

- Cambiar la arquitectura de reproducción (sigue habiendo un único `AVPlayer` vía `AudioPlayerCoordinator`).
- Acoplar la radio/autoplay al servicio de YouTube (se usa un protocolo inyectado; el servicio quedará fuera del alcance de este cambio).
- Rediseñar la pantalla bloqueada ni la caché de carátulas.
- Persistir música offline ni descargas (fuera de alcance aquí).
- Migrar persistencia a SwiftData (Core Data es deliberado).

## Decisions

### Modos de reproducción: shuffle y repeat

Se añade un modelo de estado pequeño (`PlaybackMode`) con `shuffle: Bool` y `repeatMode: RepeatMode` (`off`, `all`, `one`), publicado desde `AudioPlayerCoordinator` (o un objeto observable auxiliar) y conmutado desde `PlayerDock`.

- **Repeat one**: al llegar al final de la pista, `AudioPlayerCoordinator` vuelve a cargar la misma pista en lugar de avanzar.
- **Repeat all**: al llegar al final de la cola, se reinicia la cola (`currentIndex` al principio) y se avanza a la primera pista.
- **Shuffle**: al activarse se genera un orden de reproducción aleatorio para la cola (sin duplicar pistas) y `advance()` / `retry()` respetan ese orden; al desactivarse se restaura el orden original y la pista activa.
- La pista actual nunca se pierde al cambiar modos: si la pista activa deja de estar en la progresión, se mantiene y se reanuda desde la posición más próxima.

La semántica de cola existente (`PlaybackQueue`) se conserva; el modo shuffle se implementa como una permutación de índices asociada a la cola, no mutando el array original salvo que el reproductor lo requiera para la pista activa.

Alternativa descartada: reinventar el modelo de cola. Se reutiliza `PlaybackQueue` y se añade la capa de modos encima, respetando sus tests actuales.

### Cola reordenable por arrastre

El editor de cola (`queueEditor`) del reproductor ampliado, que hoy usa flechas `move(id:by:)`, incorpora reordenación por arrastre mediante la API nativa de `List`/`ForEach` (`onMove`) o un `dragAndDrop` equivalente en la vista de cola, llamando a `queue.move(from:to:)`. Se mantienen las flechas para acceder a la reordenación sin arrastre (accesibilidad).

### Continuar donde lo dejaste

Al reproducir una pista, `AudioPlayerCoordinator`/`AppEnvironment` guarda (periodicamente y en pausa) el `videoID` y `currentTime` actuales mediante `PlaybackSettings` → `LibraryStore.setPreference`. Al iniciar la app (`DiegoMusicApp`/`AppEnvironment`), si hay una pista guardada y el ajuste está activo, se restaura la pista en la cola y se busca a la posición guardada, sin auto‑reproducción (queda en pausa, respetando el arranque silencioso). Si el usuario lo desactiva en ajustes, no se restaura.

### Gestos del reproductor

En el estado ampliado:

- **Swipe para siguiente/anterior**: un `DragGesture` horizontal sobre la carátula (o la zona de contenidos) enruta a `player.next()` / `player.previous()` cuando el desplazamiento supera un umbral; sin acoplar a la barra de progreso.
- **Arrastrar hacia abajo para cerrar**: un `DragGesture` vertical desde la parte superior del dock ampliado que lo contrae al superar un umbral (con `@GestureState`, respetando `accessibilityReduceMotion` para la animación).

Los botones de control grandes (play/pause/anterior/siguiente) se mantienen con área táctil ≥ 44pt y etiquetas accesibles; los gestos no eliminan el acceso por botón/accesibilidad.

### Autoplay/radio best‑effort con proveedor inyectado

`AudioPlayerCoordinator` recibe un `any RelatedTrackProviding?` (protocolo inyectado, opcional):

```
protocol RelatedTrackProviding: Sendable {
    func next(after current: MediaItem, playlist: [MediaItem]) async throws -> MediaItem?
}
```

Al terminar la cola con repeat `off`, se pide una pista relacionada y, si se obtiene, se encola y se reproduce. Es best‑effort: ante error o `nil` se detiene como hasta ahora. Este cambio NO edita el servicio de YouTube; el proveedor real podrá implementarlo en otro cambio.

### Dependencia cruzada: letras (C6)

El cambio `lyrics` (C6) entregará `LyricsView` + un servicio de letras. `PlayerDock` podrá exponer una entrada "Letras" en el estado ampliado que presente `LyricsView` con la pista activa y `currentTime`. Hasta que C6 aterrice tras el merge, dicha entrada queda deshabilitada u oculta con un comentario de integración; este cambio no implementa las letras.

## Risks / Trade-offs

- [Reproducción: cambio de modos rompe cola o tests] → reutilizar `PlaybackQueue` y respetar sus tests; validar con las suites existentes.
- [Restauración reproduce en un momento no deseado] → restaurar en pausa, respetar ajuste, y guardar solo con historial/preferencia activos.
- [Gestos confluyen con el deslizamiento del slider o la navegación] → umbrales explícitos, excluir la barra de progreso y mantener botones accesibles.
- [Shuffle duplica/omite pistas] → permutación sin duplicados, preservando la pista activa; restaural al desactivar.
- [Radio best‑effort encola basura o autplay indeseado] → proveedor inyectado opcional y best‑effort; ante `nil`/error se mantiene el comportamiento actual.
- [Dependencia C6 aún no implementada] → la entrada "Letras" queda deshabilitada/placeholder hasta el merge.

## Migration Plan

1. Añadir el modelo de modos (`PlaybackMode`/`RepeatMode`) y exponerlo desde el coordinador; implementar repeat one/all y shuffle en `AudioPlayerCoordinator`/`PlaybackQueue`.
2. Persistir/restaurar posición: extensiones en `PlaybackSettings` y arranque en `AppEnvironment`/`DiegoMusicApp`.
3. Reordenación por arrastre en el editor de cola de `PlayerDock` (manteniendo flechas).
4. Gestos: swipe siguiente/anterior y arrastre para cerrar en el ampliado.
5. Autoplay/radio con `RelatedTrackProviding` inyectado.
6. Regenerar el proyecto si hay ficheros nuevos, ejecutar validaciones Swift/macOS+iOS Simulator y revisar accesibilidad (las validaciones de build se realizan en una máquina con Xcode; este entorno es Linux sin compilador Swift).

Rollback: revertir; la reproducción base y el sistema de diseño mínimo quedan intactos.

## Open Questions

- Confirmar en dispositivo si "continuar donde lo dejaste" debe auto‑reproducir o quedar en pausa al reabrir (por defecto: pausa).
- Decidir el umbral exacto del gesto de swipe/arrastre tras pruebas en dispositivo.
- Verificar que el shuffle combinado con repeat all se comporta como espera el usuario (ciclo aleatorio continuo).
