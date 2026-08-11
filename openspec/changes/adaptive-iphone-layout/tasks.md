# Tareas — Layout adaptativo para iPhone

## 1. Modificador de margen adaptativo en DesignSystem

- [x] 1.1 Añadir `ResponsiveHorizontalMarginModifier` (y extensión `responsiveHorizontalPadding`) en `DiegoMusic/Design/DesignSystem.swift` que lea `@Environment(\.horizontalSizeClass)` y aplique 16pt en compacto y 28pt en regular.

## 2. Navegación raíz adaptativa

- [x] 2.1 En `DiegoMusic/App/RootView.swift`, leer `@Environment(\.horizontalSizeClass)` y envolver en un `Group`: si compacto mostrar una nueva `PhoneTabView` (TabView con Inicio, Búsqueda, Biblioteca, Playlists, Ajustes); si regular conservar el `NavigationSplitView` actual.
- [x] 2.2 Mover el `safeAreaInset` del `PlayerDock` y el `.tint` al `Group` compartido para no duplicarlos.
- [x] 2.3 Hacer que la selección de pestaña (para `HomeView.onStartSearch`) sea compartida entre `PhoneTabView` y el enrutado de búsqueda.

## 3. Ajuste de márgenes en Home

- [x] 3.1 En `DiegoMusic/Features/Home/HomeView.swift`, sustituir el `.padding(28)` horizontal por `.responsiveHorizontalPadding()`, conservando el espaciado vertical.

## 4. Tipografías y espaciado compactos en Home

- [x] 4.1 Añadir a `HomeView` el flag `isCompact` (lectura de `horizontalSizeClass`) y usarlo para reducir el logotipo/hero, apilar las tarjetas de características en vertical, estrechar la cuadrícula de novedades y reducir espaciados y tamaños de texto en iPhone.

## 4. Pantalla completa nativa (UILaunchScreen)

- [x] 4.1 Añadir `UILaunchScreen: {}` a `Config/Info.plist` y `project.yml` para evitar que iOS ejecute la app en modo compatibilidad legado (con barras negras horizontales/verticales).

## 5. Validación

- [x] 5.1 Regenerar el proyecto solo si cambian fuentes/recursos y ejecutar validaciones Swift (`./scripts/validate.sh` en máquina con Xcode).
- [x] 5.2 Validar el cambio OpenSpec estricto (`openspec validate adaptive-iphone-layout --type change --strict`).
- [x] 5.3 Verificar en simulador/dispositivo iPhone que Inicio abre a pantalla completa nativa con barra de pestañas, sin barras de compatibilidad ni márgenes verticales excesivos, y que iPad/macOS conservan el split.
