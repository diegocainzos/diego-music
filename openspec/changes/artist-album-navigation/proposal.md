# Cambio: Navegación a Perfil de Artista y Álbum

## Why

Actualmente, las vistas `ArtistView` y `AlbumView` existen en el proyecto, pero no disponen de un flujo unificado de navegación o presentación modal (sheet/NavigationLink) accesible desde los resultados de búsqueda, las filas de canciones ni el menú contextual del reproductor. Permitir navegar al perfil de un artista o al álbum desde cualquier canción mejora significativamente la descubribilidad y la experiencia de navegación de la app.

## What Changes

- **Destinos de navegación / Sheets de Artista y Álbum**: Implementar la infraestructura de presentación modal/sheet para abrir `ArtistView` (con `artistID` / `channelTitle`) y `AlbumView` (con `playlistID` / `albumTitle`) desde cualquier vista.
- **Acciones en el Menú Contextual**: Integrar las opciones "Ver artista" y "Ver álbum" en el menú de 3 puntos de las filas de resultados de búsqueda (`SearchResultRow`) y biblioteca.
- **Resolución y Fallback por Nombre**: Permitir la resolución y apertura del perfil de artista usando el título del canal (`channelTitle`) si el identificador explícito de canal no estuviera presente.

## Capabilities

### New Capabilities

- `artist-album-navigation`: Navegación y presentación modal fluida hacia la vista de detalle de artista (`ArtistView`) y de álbum/lista (`AlbumView`) desde canciones, búsquedas y reproductor.

### Modified Capabilities

<!-- No hay baseline archivado en openspec/specs/. -->

## Impact

- Cliente Swift: `DiegoMusic/Features/Home/ArtistView.swift`, `DiegoMusic/Features/Home/AlbumView.swift`, `DiegoMusic/Features/Search/SearchView.swift`, `DiegoMusic/App/RootView.swift`.
- No requiere cambios en ResolverService ni en la arquitectura de audio.
