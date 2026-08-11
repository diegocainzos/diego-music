## Context

DiegoMusic reproduce audio nativo con una única `AVPlayer` coordinada por `AudioPlayerCoordinator`, que ya publica título, artista, duración, posición y velocidad en `MPNowPlayingInfoCenter` y registra play/pause/siguiente/anterior/seek en `MPRemoteCommandCenter`. La pantalla bloqueada y el centro de control ya funcionan, pero no muestran carátula: `updateNowPlayingInfo` nunca asigna `MPMediaItemPropertyArtwork`.

La interfaz actual es Bauhaus Hi‑Fi: superficies crema/papel, trazos de tinta de 2px, sombras de offset duras, tipografía `.rounded` en pesos black y acentos primarios rojo/amarillo/azul, definidos en `DesignSystem.swift` y usados por 9 ficheros Swift. Esta identidad está especificada en el delta `bauhaus-hifi-design-system` (cambio `build-diego-music-v1`, aún sin archivar), que también contiene los requisitos de accesibilidad (labels, reduce motion, contraste) que deben sobrevivir a la retirada.

## Goals / Non-Goals

**Goals:**

- Sustituir la identidad Bauhaus por un sistema de diseño mínimo tipo Apple Music en toda la app.
- Rediseñar el reproductor (compacto y ampliado) con carátula protagonista y fondo ambiental.
- Mostrar la carátula real de la pista en pantalla bloqueada y centro de control.
- Cachear carátulas de forma pequeña y compartida entre la UI del reproductor y el Now Playing.
- Preservar la accesibilidad existente y la semántica de cola/AVPlayer sin cambios.
- Mantener el rojo actual de DiegoMusic como único acento.

**Non-Goals:**

- Copiar literalmente el diseño de Apple Music o usar sus marcas.
- Añadir un conmutador de temas: Bauhaus desaparece; no hay tema alternativo.
- Cambiar la arquitectura de reproducción, resolución, cola o persistencia.
- Rediseñar la pantalla bloqueada (pertenece al sistema); solo se publica carátula.
- Añadir dependencias externas de UI o de imágenes.

## Decisions

### Retirar Bauhaus y definir tokens semánticos mínimos

`DesignSystem.swift` se reescribe: tokens por rol (`background`, `surface`, `textPrimary`, `textSecondary`, `accent`) en lugar de por color físico, tipografía de sistema SF (sin `.rounded` black), esquinas redondeadas moderadas, sombras suaves o ausentes. El único acento es el rojo actual de DiegoMusic (`Color(red: 0.88, green: 0.22, blue: 0.17)`).

Los componentes Bauhaus (`BauhausCardModifier`, `HiFiButtonStyle`, `SectionHeader`, `RecordPlaceholder`) se sustituyen por equivalentes mínimos (tarjeta sin borde duro, botón de relleno suave, cabecera sencilla). `EmptyStateView` y las vistas de features se portan.

Alternativa descartada: mantener Bauhaus y añadir un tema nuevo seleccionable. Duplica el mantenimiento y contradice la decisión del usuario de reemplazar la identidad.

### Rediseño del reproductor

`PlayerDock` conserva su estructura de dos estados (compacto / ampliado) y toda la semántica de AVPlayer/cola, pero cambia la presentación: carátula redondeada protagonista, fondo ambiental derivado de la carátula (degradado suave, respetando `accessibilityReduceMotion`), controles SF Symbols sin bordes duros y barra de progreso fina. La factoría `artwork(_:size:)` pasa a servir la imagen cacheada en lugar de `AsyncImage` directo, para que reproductor y lockscreen compartan el mismo arte.

### Caché pequeña de carátulas

Un actor `ArtworkCache` (memoria, LRU mínimo, TTL de una sesión) guarda `UIImage` claveado por URL de carátula. Sirve a dos consumidores: el `AsyncImage` de la UI del reproductor y el `MPMediaItemPropertyArtwork` de Now Playing. Tamaño contenido (por ejemplo ≤ 32 entradas); al fallar, cada consumidor mantiene su placeholder actual. Se añade solo si se requiere un fichero nuevo; en ese caso se regenera `project.yml` con `./scripts/generate-project.sh`.

Alternativa descartada: carátula one‑shot sin caché. El usuario pidió explícitamente caché; además la reutilización entre reproductor y lockscreen evita descargas duplicadas por pista.

### Carátula en pantalla bloqueada

`AudioPlayerCoordinator.updateNowPlayingInfo` carga la carátula de forma asíncrona (fuera del actor principal, en una tarea `Task` de carga de imagen) y asigna `MPMediaItemPropertyArtwork(MPMediaItemArtwork(boundsSize:image.size, requestHandler: { _ in image }))`. La pista `MediaItem.thumbnailURL` (~`high`, 480px) es suficiente; se descarta de momento `maxres`. El flujo nunca bloquea el hilo principal: si la carga no ha terminado, se publican los metadatos de texto y la carátula llega cuando esté lista.

### Accesibilidad preservada y re-especificada

Los requisitos de accesibilidad que viven hoy en el spec Bauhaus (etiquetas accesibles en controles, `accessibilityReduceMotion`, contraste, áreas táctiles ≥ 44pt) se reafirman como requisitos propios del nuevo spec, para que retirar Bauhaus no los elimine.

## Risks / Trade-offs

- [Pérdida silenciosa de accesibilidad al retirar Bauhaus] → re-especificar labels/reduce-motion/contraste como requisitos propios del nuevo spec y mantenerlos en la revisión de cada vista.
- [Carátula del lockscreen tarda en aparecer o falla] → publicación asíncrona de metadatos con carátula opcional; el texto siempre se publica y la carátula llega cuando esté lista.
- [Caché crece sin control] → límite de entradas y reemplazo LRU mínimo; al fallar, placeholders existentes.
- [Cambio cosmético rompe pruebas o build] → validaciones obligatorias (validate.sh, xcodebuild test, build-for-testing iOS Simulator) y regeneración de proyecto si hay ficheros nuevos.
- [Dependencias entre workers que portan vistas y el nuevo DesignSystem] → el contrato del nuevo `DesignSystem.swift` (nombres de tokens y componentes) se fija en las tareas antes de delegar.

## Migration Plan

1. Reescribir `DesignSystem.swift` (tokens + componentes mínimos) con el contrato de API fijado.
2. Añadir la caché de carátulas y la publicación de `MPMediaItemPropertyArtwork` (independiente de la UI).
3. Portar vistas (Home, Library, Playlists, Search, Settings, RootView, EmptyStateView) al nuevo sistema.
4. Rediseñar `PlayerDock` consumiendo la caché de carátulas.
5. Regenerar el proyecto si hay ficheros nuevos, ejecutar validaciones y revisar que la accesibilidad sigue intacta.

Rollback: revertir el cambio con el sistema Bauhaus intacto; la lógica de reproducción no se toca.

## Open Questions

- Verificar en iPhone si iOS genera el fondo difuminado de la carátula en lockscreen automáticamente o si requiere una futura mejora (fuera de alcance aquí).
- Decidir tras el primer uso si `maxres` merece el coste de una segunda URL de carátula en `MediaItem`.