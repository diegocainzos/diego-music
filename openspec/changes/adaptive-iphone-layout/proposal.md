# Cambio: layout adaptativo para iPhone

## Why

En iPhone (horizontalSizeClass compacto) el `NavigationSplitView` con estilo `.prominentDetail` se comporta mal: la app abre mostrando la lista lateral (DiegoMusic / Inicio / Búsqueda / …) como pantalla raíz en lugar de `Inicio`, y el contenido del detail se apila con insets y márgenes que no quedan bien ajustados a la pantalla. En `HomeView` los márgenes se notan mal ajustados y la experiencia se siente incorrecta.

## What Changes

- **Navegación raíz adaptativa**: usar `TabView` (barra inferior nativa de iPhone) en `horizontalSizeClass == .compact`, y mantener el `NavigationSplitView` actual solo en iPad/macOS (size class regular).
- **Ajuste de márgenes en compact**: reducir el margen horizontal fijo (28pt) a un margen adaptativo (16pt en compact, 28pt en regular) para el contenido de pantallas, empezando por `HomeView`.
- **Reutilizable**: añadir un modificador de padding horizontal adaptativo en `DesignSystem` para mantener consistencia entre vistas.

## Capabilities

### New Capabilities

- `adaptive-layout`: navegación raíz adaptativa por tamaño de clase (`TabView` en compact para iPhone, `NavigationSplitView` en regular para iPad/macOS) y márgenes horizontales adaptativos del contenido.

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ está vacío). No se modifican requisitos de capacidades existentes a nivel de spec. -->

## Impact

- Cliente Swift: `DiegoMusic/App/RootView.swift` (navegación raíz adaptativa), `DiegoMusic/Design/DesignSystem.swift` (modificador de margen adaptativo), `DiegoMusic/Features/Home/HomeView.swift` (margen horizontal adaptativo). Posible alineación puntual en `LibraryView`, `PlaylistsView`, `SearchView` y `SettingsView`.
- No hay cambios en ResolverService, API de YouTube ni persistencia. La arquitectura de un único `AVPlayer` se conserva.
- Se regenera el proyecto solo si se añaden ficheros nuevos (no es el caso).
