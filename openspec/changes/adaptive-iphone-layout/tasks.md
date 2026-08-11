# Tareas — Layout adaptativo para iPhone

## 1. Modificador de margen adaptativo en DesignSystem

- [x] 1.1 Añadir `ResponsiveHorizontalMarginModifier` (y extensión `responsiveHorizontalPadding`) en `DiegoMusic/Design/DesignSystem.swift` que lea `@Environment(\.horizontalSizeClass)` y aplique 16pt en compacto y 28pt en regular.

## 2. Navegación raíz adaptativa

- [x] 2.1 En `DiegoMusic/App/RootView.swift`, leer `@Environment(\.horizontalSizeClass)` y envolver en un `Group`: si compacto mostrar una nueva `PhoneTabView` (TabView con Inicio, Búsqueda, Biblioteca, Playlists, Ajustes); si regular conservar el `NavigationSplitView` actual.
- [x] 2.2 Mover el `safeAreaInset` del `PlayerDock` y el `.tint` al `Group` compartido para no duplicarlos.
- [x] 2.3 Hacer que la selección de pestaña (para `HomeView.onStartSearch`) sea compartida entre `PhoneTabView` y el enrutado de búsqueda.

## 3. Ajuste de márgenes en Home

- [x] 3.1 En `DiegoMusic/Features/Home/HomeView.swift`, sustituir el `.padding(28)` horizontal por `.responsiveHorizontalPadding()`, conservando el espaciado vertical.

## 4. Validación

- [x] 4.1 Regenerar el proyecto solo si cambian fuentes/recursos (no se espera) y ejecutar validaciones Swift (`./scripts/validate.sh` en máquina con Xcode).
- [x] 4.2 Validar el cambio OpenSpec estricto (`openspec validate adaptive-iphone-layout --type change --strict`).
- [ ] 4.3 Verificar en simulador/dispositivo iPhone que Inicio abre a pantalla completa con barra de pestañas y márgenes correctos, y que iPad/macOS conservan el split.
