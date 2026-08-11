## 1. Sistema de diseño mínimo

- [x] 1.1 Reescribir `DesignSystem.swift`: tokens semánticos (background/surface/text/accent), tipografía de sistema, esquinas redondeadas, sombras suaves, acento rojo actual; sustituir `BauhausCardModifier`, `HiFiButtonStyle`, `SectionHeader` y `RecordPlaceholder` por componentes mínimos equivalentes.
- [x] 1.2 Renovar `EmptyStateView` y `RootView` al nuevo sistema de diseño.

## 2. Caché de carátulas y Now Playing

- [x] 2.1 Implementar actor `ArtworkCache` (memoria, LRU mínimo, límite de entradas) que sirva imágenes por URL.
- [x] 2.2 Publicar `MPMediaItemPropertyArtwork` en `AudioPlayerCoordinator` desde la caché, de forma asíncrona y sin bloquear el hilo principal.
- [x] 2.3 Integrar la caché en el `AsyncImage` del reproductor para reutilizar la misma carátula.

## 3. Portar vistas al nuevo sistema

- [x] 3.1 Portar `HomeView` y `SearchView`.
- [x] 3.2 Portar `LibraryView` y `PlaylistsView`.
- [x] 3.3 Portar `SettingsView`.

## 4. Reproductor rediseñado

- [x] 4.1 Rediseñar `PlayerDock` compacto y ampliado (carátula protagonista, fondo ambiental derivado de la carátula, controles SF Symbols, progreso fino) conservando semántica de cola y accesibilidad con `accessibilityReduceMotion`.

## 5. Validación

- [x] 5.1 Regenerar el proyecto si hay ficheros nuevos y ejecutar validaciones Swift/macOS+iOS Simulator.
- [x] 5.2 Validar el cambio OpenSpec estricto y revisar que la accesibilidad no se ha perdido en ninguna vista.