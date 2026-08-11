# Diseño Técnico: Ajustes visuales, temas y correcciones de layout

## Contexto

La interfaz requiere un acabado idéntico a Apple Music Web tanto en Modo Claro como en Modo Oscuro, asegurando que la navegación y los insets del reproductor funcionen sin solapamientos ni problemas de interacción táctil.

## Arquitectura de Componentes

1. **`DiegoTheme` Adaptativo**:
   - `background(for scheme: ColorScheme)`
   - `surface(for scheme: ColorScheme)`
   - `textPrimary(for scheme: ColorScheme)`
   - `textSecondary(for scheme: ColorScheme)`
   - `accent`: `#FA2D48`

2. **`HomeView` ("Listen Now")**:
   - `HeroCarouselView`: Tarjetas promocionales de 340x220pt con bordes de 16pt y degradados protectores.
   - `TopArtistsRow`: Avatares circulares de 110pt (`Circle()`) con navegación a `ArtistView`.
   - `RecomendacionesGrid`: Rejilla adaptativa de carátulas cuadradas.

3. **`RootView` & Layout Insets**:
   - Reestructurado del contenedor principal usando `ZStack` + `VStack(spacing: 0)` o `safeAreaInset` donde el `PlayerDock` se sitúa estrictamente por encima de la barra de pestañas.
   - `selectTab`: Resetea la pila de rutas cuando se vuelve a pulsar la pestaña actualmente seleccionada.
