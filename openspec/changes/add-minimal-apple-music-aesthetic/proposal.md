## Why

La identidad Bauhaus Hi‑Fi queda lejos de la experiencia musical que el usuario espera: la pantalla bloqueada no muestra carátula (el coordinador publica metadatos sin `MPMediaItemPropertyArtwork`) y la interfaz in‑app prioriza el carácter gráfico sobre la música. DiegoMusic necesita una estética mínima tipo Apple Music —superficies claras, tipografía de sistema, carátula protagonista— y que la pantalla bloqueada muestre la portada real de la pista.

## What Changes

- **BREAKING**: retirar la identidad visual Bauhaus Hi‑Fi (trazos de tinta de 2px, sombras duras, superficies crema/papel, acentos rojo/amarillo/azul) y sustituirla por un sistema de diseño mínimo tipo Apple Music en toda la app.
- Redefinir `DesignSystem.swift`: tokens semánticos (fondo/superficie/texto), tipografía de sistema SF, esquinas redondeadas, sombras suaves o ausentes y un único acento (el rojo actual de DiegoMusic, conservado).
- Reemplazar los componentes Bauhaus (`BauhausCardModifier`, `HiFiButtonStyle`, `SectionHeader`, `RecordPlaceholder`) por equivalentes mínimos y portar todas las vistas (Home, Library, Playlists, Search, Settings, RootView, EmptyStateView) al nuevo sistema.
- Rediseñar `PlayerDock` (compacto y ampliado) en estilo mínimo con carátula protagonista y fondo ambiental derivado de la carátula.
- Añadir una caché pequeña de carátulas que sirva tanto a la UI del reproductor como a la pantalla bloqueada.
- Publicar la carátula en la pantalla bloqueada y centro de control mediante `MPMediaItemPropertyArtwork` en `AudioPlayerCoordinator`.
- Reafirmar como requisitos propios la accesibilidad que hoy vive dentro del spec Bauhaus (etiquetas, `accessibilityReduceMotion`, contraste, foco), para no perderla al retirar Bauhaus.

## Capabilities

### New Capabilities

- `minimal-apple-music-aesthetic`: sistema de diseño mínimo tipo Apple Music aplicado en toda la app, reproductor rediseñado, caché de carátulas y publicación de carátula en la pantalla bloqueada.

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ no existe aún). `bauhaus-hifi-design-system` y `native-audio-playback` viven como deltas en cambios en curso; este cambio los SUPERSEDE: retira los requisitos Bauhaus y amplía el segundo plano/Now Playing con carátula. -->

## Impact

- Cliente: `DesignSystem`, `EmptyStateView`, `RootView`, las cinco vistas de features, `PlayerDock`, `AudioPlayerCoordinator`, `MediaItem` (carátula cacheada opcional) y `project.yml` si hay ficheros nuevos.
- Comportamiento: la pantalla bloqueada pasa de texto sin carátula a texto + portada real.
- Sin cambios en ResolutionService, API de YouTube, persistencia ni lógica de cola/AVPlayer.
- La accesibilidad existente (labels, reduce motion, contraste) se conserva y se explicita en el nuevo spec.