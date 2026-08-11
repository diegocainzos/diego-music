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

### Requirement: Tipografías y espaciado compactos en Home

En `horizontalSizeClass == .compact`, la pantalla Inicio SHALL usar tipografías y espaciados reducidos para aprovechar la pantalla y mejorar la navegación: logotipo/hero más pequeño, tarjetas de características apiladas verticalmente, cuadrícula de novedades con columnas más estrechas y espaciado vertical contenido. En tamaño regular se conserva la versión amplia actual.

#### Scenario: Hero compacto
- **WHEN** la pantalla Inicio se renderiza en compacto
- **THEN** el logotipo DIEGO MUSIC usa un tamaño menor que en regular
- **AND** el bloque hero ocupa menos altura mínima

#### Scenario: Características en compacto
- **WHEN** la pantalla Inicio se renderiza en compacto
- **THEN** las tres tarjetas de características se apilan verticalmente en lugar de en tres columnas ilegibles

#### Scenario: Novedades en compacto
- **WHEN** la pantalla Inicio se renderiza en compacto
- **THEN** la cuadrícula usa columnas más estrechas y carátulas más bajas que en regular
