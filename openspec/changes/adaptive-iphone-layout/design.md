# Design — Layout adaptativo para iPhone

## Context

La raíz de navegación es un `NavigationSplitView` con `.prominentDetail`, diseñado para pantallas amplias (iPad/macOS). En iPhone (compacto) SwiftUI lo colapsa a una sola columna y muestra el listado lateral como pantalla raíz, produciendo una experiencia con márgenes e insets mal ajustados. El contenido de las pantallas usa un margen horizontal fijo de 28pt, excesivo en compacto.

## Goals / Non-Goals

**Goals**:
- Raíz adaptativa: `TabView` en compacto para una experiencia nativa de iPhone (barra inferior, cada pestaña a pantalla completa).
- Margen horizontal adaptativo (16pt compacto / 28pt regular) reutilizable para mejorar el ajuste del contenido en `HomeView`.
- Mantener la rama `NavigationSplitView` intacta en regular.

**Non-Goals**:
- No se rediseña el player ampliado ni la arquitectura de reproducción.
- No se toca ResolverService, YouTube ni persistencia.
- No se reimplementa navegación custom por gestos.

## Decisions

### D1. Ramificar por `horizontalSizeClass` en la raíz
`RootView` lee `@Environment(\.horizontalSizeClass)` y muestra un `Group { if compact → PhoneTabView else → SplitRootView }`. El `safeAreaInset` del `PlayerDock` y el `.tint` se aplican al `Group` para no duplicarlos.
**Alternativas**: basarse en `UIDevice.current.userInterfaceIdiom`; descartado porque el idioma no refleja rotación/multitarea (Split View). `horizontalSizeClass` es la fuente canónica de SwiftUI.

### D2. `TabView` como raíz en compacto
`PhoneTabView` declara las cinco pestañas (Inicio, Búsqueda, Biblioteca, Playlists, Ajustes) con `.tabItem`. Cada destino se envuelve en su propio `NavigationStack`/`ScrollView` existente. `HomeView.onStartSearch` pasa a seleccionar la pestaña de Búsqueda mediante un binding compartido (por ejemplo `@Binding var selection: AppDestination` o un `@EnvironmentObject`).
**Alternativas**: `NavigationSplitView` corregido con `navigationSplitViewBehavior`; descartado porque en compacto sigue empujando pantallas en lugar de dar una barra de pestañas estable.

### D3. Modificador de margen adaptativo en `DesignSystem`
Nuevo `ResponsiveHorizontalMarginModifier` que lee `horizontalSizeClass` y aplica 16pt (compacto) / 28pt (regular) mediante `.padding(.horizontal, ...)`. Se reutiliza en las vistas de contenido.
**Alternativas**: `GeometryReader`; descartado por costo y complejidad innecesaria en una dimensión horizontal simple.

## Risks / Trade-offs

- [Cambiar la navegación raíz puede romper tests de UI que asuman el split] → Mitigación: no hay tests de UI activos; se validan vistas y navegación en dispositivo físico.
- [Duplicar el vinculado entre `HomeView.onStartSearch` y la pestaña Búsqueda] → Mitigación: selección compartida vía binding/env object, sin lógica duplicada.
- [El dock se solapa con la barra de pestañas] → Mitigación: `TabView` coloca el `safeAreaInset` por encima de la barra de pestañas; verificar visualmente que no quede cubierto.

## Migration Plan

Cambio de solo cliente Swift, sin migración de datos. Rollback: revertir `RootView` y `DesignSystem`.

## Open Questions

- ¿Alinear también `LibraryView`, `SearchView`, `PlaylistsView` y `SettingsView` al margen adaptativo en este cambio o en uno posterior? (Por defecto solo `HomeView`, con el modificador listo para reutilizar.)
