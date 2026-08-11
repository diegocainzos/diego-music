# Diseño Técnico: Apple Music Overhaul

## Contexto

El objetivo es alcanzar la paridad total con la interfaz oficial de Apple Music Web en identidad visual, componentes, variabilidad de catálogo y navegación.

## Componentes y Arquitectura

1. **Logo & Temas**:
   - `AppleMusicLogoView`: Icono con nota musical roja y texto "Music".
   - `AppThemeMode`: Modo Oscuro por defecto, Modo Claro y Modo Sistema con persitencia en `PlaybackSettings`.

2. **Escuchar (Listen Now)**:
   - `HomeViewModel`: Servicio con catálogo variado (Nas, Karol G, Radiohead, Daft Punk, Kendrick Lamar, Taylor Swift, Drake).
   - `HeroCarouselView` & `TopArtistsRow` (avatares circulares de 110pt).

3. **ArtistView & Playlist Creation**:
   - `CreatePlaylistSheet`: Modal para nombre, portada y guardado inmediato en `LibraryStore`.
   - `ArtistView`: Header con foto grande, badge verificado, botones cápsula "Reproducir" y "Aleatorio", éxitos populares numerados.
