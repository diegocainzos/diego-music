# Diseño: Navegación a Perfil de Artista y Álbum

## Contexto

En DiegoMusic, `ArtistView` requiere un `artistID` (channelID de YouTube) y `artistTitle`, mientras que `AlbumView` requiere un `playlistID`. En los resultados de búsqueda y filas de canciones (`MediaItem`), disponemos de `channelTitle` y a veces de un identificador de canal/álbum.

## Decisiones de Diseño

1. **Presentación via Sheet / NavigationDestination**:
   - Para mantener compatibilidad tanto con `TabView` en modo compacto (iPhone) como con `NavigationSplitView` en regular (iPad/macOS), se proporciona un estado de presentación mediante `.sheet` modal reutilizable que envuelve `ArtistView` y `AlbumView` en su propio `NavigationStack`.
   - Se define una estructura `NavigationDestination: Identifiable` que encapsula el tipo de destino (`artist` o `album`) con sus argumentos asociados.

2. **Resolución diferida (Fallback por nombre)**:
   - Si se solicita navegar a un artista utilizando solo `channelTitle`, la vista realiza la búsqueda y resolución del canal automáticamente para presentar el perfil sin interrumpir al usuario.

3. **Integración en Menú de 3 Puntos**:
   - El menú contextual de cada fila de resultados de búsqueda incluirá:
     - "Ver artista" (`systemImage: "music.mic"`) -> abre `ArtistView`.
     - "Ver álbum / lista" (`systemImage: "square.stack"`) -> abre `AlbumView`.
