## Why

DiegoMusic ya reproduce audio de forma fiable con una única `AVPlayer`, con cola, controles y Now Playing operativos. Pero le faltan los hábitos centrales de un reproductor de música usado cada día: no recuerda dónde te quedaste al reabrir la app, no ofrece shuffle/repeat, la cola no admite arrastrar para "tocar para poner después", el reproductor ampliado no se cierra con el gesto natural de arrastre hacia abajo ni permite deslizar para pasar de canción, y no continúa con música relacionada al terminar una lista. Estas piezas llenan la experiencia "imprescindible" que el usuario espera de un reproductor, sin tocar la arquitectura de reproducción ni la privacidad.

## What Changes

- **Modos de reproducción**: añadir shuffle y repeat (pista / lista / off) conmutables desde el reproductor, respetando la pista activa y la semántica de la cola.
- **Cola reordenable por arrastre**: permitir "toca para poner después" — reordenar la cola arrastrando elementos (además de las flechas existentes) en el editor de cola del reproductor ampliado.
- **Continuar donde lo dejaste**: persistir la pista activa (y su posición `currentTime`) usando el almacén local de preferencias/Core Data de `LibraryStore` y restaurarla al reabrir la app, de forma opcional y respetada por ajustes.
- **Controles grandes y gestos**: gesto de deslizar (swipe) en el reproductor ampliado para ir a siguiente/anterior, y arrastrar hacia abajo para cerrar el reproductor ampliado, buscando las áreas táctiles reducidas por el gesto con botones de 44pt.
- **Autoplay / radio best‑effort**: al terminar la cola (o una lista), solicitar una pista relacionada mediante un proveedor inyectado (`RelatedTrackProviding`) sin acoplar este cambio al servicio de YouTube.
- Reafirmar como requisitos propios: un único `AVPlayer` coordinado por `AudioPlayerCoordinator`, audio en segundo plano, Now Playing/carátula y accesibilidad (etiquetas, `accessibilityReduceMotion`, contraste, foco).

## Capabilities

### New Capabilities

- `player-experience`: modos de reproducción (shuffle/repeat), cola reordenable por arrastre, restauración de la reproducción, gestos del reproductor y autoplay/radio con proveedor inyectado, preservando la reproducción nativa y la accesibilidad.

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ no existe aún). `native-audio-playback` vive como delta en el cambio en curso `add-vps-audio-playback`; este cambio AMPLÍA ese comportamiento (repeat/shuffle/restauración/gestos) sin reemplazarlo. -->

## Impact

- Cliente: `AudioPlayerCoordinator`, `PlaybackQueue`, `PlayerDock`, `PlaybackSettings`, `AppEnvironment`, `DiegoMusicApp`; ficheros nuevos bajo `DiegoMusic/` (p. ej. un modelo de modos de reproducción y un proveedor `RelatedTrackProviding`) si se requieren — se regenera `project.yml` en ese caso.
- Comportamiento: la app recuerda la reproducción, ofrece shuffle/repeat, cola reordenable y gestos, y encadena música relacionada al terminar.
- Sin cambios en ResolverService, API de YouTube ni persistencia de catálogo. La arquitectura de un único `AVPlayer` se conserva.
- Dependencia cruzada a futuro: el cambio `lyrics` (C6) entregará `LyricsView` + un servicio de letras; `PlayerDock` podrá exponer una entrada "Letras" que referencia esos tipos tras el merge (se detalla en design).
