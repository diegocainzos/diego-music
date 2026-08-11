## ADDED Requirements

### Requirement: Navegación raíz adaptativa

La raíz de la app SHALL seleccionar su navegación según el `horizontalSizeClass` del entorno: en tamaño compacto (iPhone) usará una `TabView` con barra de pestañas inferior nativa que expone Inicio, Búsqueda, Biblioteca, Playlists y Ajustes; en tamaño regular (iPad/macOS) conservará el `NavigationSplitView` con el listado lateral actual. En ambos casos se mantiene el `PlayerDock` como `safeAreaInset` inferior y el tint de acento común.

#### Scenario: Apertura en iPhone (compacto)
- **WHEN** la app se ejecuta en un dispositivo con `horizontalSizeClass == .compact` (p. ej. iPhone 14)
- **THEN** se muestra una `TabView` con la pestaña **Inicio** activa y el contenido de `HomeView` de lleno en pantalla, sin listado lateral

#### Scenario: Apertura en iPad o macOS (regular)
- **WHEN** la app se ejecuta en un dispositivo con `horizontalSizeClass == .regular`
- **THEN** se conserva el `NavigationSplitView` con el listado lateral y el detalle actual

#### Scenario: Dock del reproductor en ambas ramas
- **WHEN** se renderiza cualquier rama de navegación
- **THEN** el `PlayerDock` se muestra como `safeAreaInset` inferior en ambas

### Requirement: Márgenes horizontales adaptativos

El contenido de las pantallas SHALL usar un margen horizontal adaptativo que varíe según el `horizontalSizeClass`: 16pt en tamaño compacto y 28pt en tamaño regular. El margen se expone como modificador reutilizable en `DesignSystem` y se aplica al menos en `HomeView`.

#### Scenario: Contenido en compacto
- **WHEN** una pantalla se renderiza en `horizontalSizeClass == .compact`
- **THEN** su contenido usa 16pt de margen horizontal
- **AND** el contenido no queda pegado a los bordes ni duplica insets por la navegación

#### Scenario: Contenido en regular
- **WHEN** una pantalla se renderiza en `horizontalSizeClass == .regular`
- **THEN** su contenido usa 28pt de margen horizontal
