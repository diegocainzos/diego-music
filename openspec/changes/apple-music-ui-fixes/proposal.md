# Cambio: Ajustes visuales, temas claro/oscuro y correcciones de layout

## Why

Para garantizar la máxima calidad UI/UX estilo Apple Music Web, es necesario añadir soporte nativo dinámico para Modo Claro y Modo Oscuro, incorporar la sección "Escuchar" completa con banners Hero y avatares circulares de Top Artistas, y solucionar bugs de maquetación donde el mini-player tapaba la barra de pestañas o impedía resetear la pila de rutas.

## What Changes

- **Sistema de diseño y temas**: Definición de `DiegoTheme` adaptativo para Modo Claro (`#FFFFFF`/`#F2F2F7`) y Modo Oscuro (`#000000`/`#1C1C1E`) con acento rojo Apple (`#FA2D48`) y efectos glassmorphism.
- **Rediseño de Home ("Listen Now")**: Banners promocionales Hero con degradados, sección de Top Artistas con avatares circulares y recomendaciones.
- **Correcciones de Layout y Navegación**: Insets seguros en `RootView` para que el `PlayerDock` flote por encima del `TabBar` sin tapar botones, y reseteo de la pila de navegación al pulsar la pestaña activa.
- **QA Visual E2E**: Generación de capturas de pantalla en ambos temas para verificación visual.

## Capabilities

### Modified Capabilities

- `ui-architecture`: soporte adaptativo para Modo Claro y Oscuro con acento `#FA2D48`.
- `layout-navigation`: corrección de z-index del PlayerDock y reseteo de rutas al pulsar en la barra de pestañas.

## Impact

- Cliente Swift: `DiegoMusic/Design/DesignSystem.swift`, `DiegoMusic/App/RootView.swift`, `DiegoMusic/Features/Home/HomeView.swift`, `DiegoMusic/Features/Player/PlayerDock.swift`.
