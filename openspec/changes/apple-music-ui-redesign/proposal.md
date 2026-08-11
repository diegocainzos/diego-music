# Cambio: Rediseño Integral de la Interfaz Apple Music Web

## Why

Para elevar la experiencia visual y funcional de la aplicación DiegoMusic a una calidad comercial idéntica a Apple Music Web, es necesario realizar un rediseño visual y arquitectónico completo. Esto incluye adoptar el sistema de diseño exacto de Apple Music Web (acentos rojo vibrante `#FA233C`, materiales glassmorphism, jerarquía de diseño oscuro/claro y tipografía SF Pro), un historial de navegación real con botones Atrás `<` y Adelante `>`, y un dock de reproductor superior/flotante con control de volumen, scrubber interactivo, botones de letras y cola.

## What Changes

- **Sistema de diseño Apple Music Web (`ui-architecture`)**:
  - Definición de tokens de color unificados (`#FA233C` acento primario, superficies oscuras translucidas con blur, bordes con sutil opacidad).
  - Componentes compartidos de barra lateral (Sidebar) para escritorio/regular y barra de pestañas (TabView) adaptativa para compacto (iPhone).
  - Tipografía estructurada basada en SF Pro / Inter.
- **Historial de Navegación (`navigation-history`)**:
  - Implementación de un gestor de pila de navegación (`NavigationHistoryManager`) que mantiene el stack de pantallas visitadas.
  - Exposición de controles de navegación "Atrás" (`<`) y "Adelante" (`>`) en la barra superior o cabecera principal.
- **Reproductor Dock Superior / Flotante (`player-dock`)**:
  - Dock estético de Apple Music Web con carátula de canción, título, canal/artista, botón de favoritos, scrubber de progreso interactivo con indicación de tiempo (0:00 / 0:00), selector de volumen, shuffle, repeat, botón de letras y panel de cola.

## Capabilities

### New Capabilities

- `apple-music-ui`: interfaz clonada de Apple Music Web con barra lateral integrada, barra superior con navegación por historial, reproductor dock flotante y tokens de diseño glassmorphism.
- `navigation-history`: pila de navegación completa con soporte para desandar (`back`) y avanzar (`forward`) entre pantallas.
- `apple-music-player-dock`: dock de reproducción estilo Apple Music Web con scrubber, volumen y accesos a letras y cola.

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ está vacío). No se modifican requisitos de capacidades existentes a nivel de spec. -->

## Impact

- Cliente Swift:
  - `DiegoMusic/Design/DesignSystem.swift` (actualización a tokens Apple Music `#FA233C`, glassmorphism y superficies).
  - `DiegoMusic/App/RootView.swift` (navegación integrada con barra lateral y controles de historial Atrás/Adelante).
  - `DiegoMusic/Features/Player/PlayerDock.swift` (rediseño completo del reproductor estilo Apple Music Web con scrubber, volumen y controles laterales).
  - `DiegoMusic/Features/Home/HomeView.swift`, `SearchView.swift`, `LibraryView.swift` (alineación visual a las capturas de referencia).
- No modifica ResolverService, `yt-dlp` ni persistencia Core Data existente.
