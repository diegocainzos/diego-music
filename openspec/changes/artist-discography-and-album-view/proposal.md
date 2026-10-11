## Why

Actualmente, el perfil del artista (`ArtistView`) muestra canciones populares y recomendaciones en la sección de discografía, sin consultar los álbumes/playlists oficiales reales del canal del artista ni permitir navegar a álbumes estructurados. Además, la vista de álbum (`AlbumView`) requiere un rediseño que cumpla con la especificación de diseño inmersiva: cabecera con carátula de gran formato, título superior, autores abajo con enlace interactivo al perfil, y un tracklist ordenado y limpio sin enumeración de pistas `#`.

## What Changes

- **Búsqueda y consulta de álbumes/playlists en YouTube Data API:** Añadir soporte en `YouTubeEndpoint` y `YouTubeDataService` para consultar las playlists/álbumes del canal de un artista (`kind: .playlists(channelID:)` o búsqueda `type=playlist`).
- **Modelo de perfil de artista enriquecido:** Incorporar `albums: [Album]` en `ArtistDetail` para almacenar y presentar la discografía real de cada artista.
- **Sección de Discografía en `ArtistView`:** Reemplazar los videos de relleno por la cuadrícula de álbumes reales del artista, navegando directamente a `AlbumView` con el `playlistID`.
- **Rediseño inmersivo de `AlbumView`:**
  - Carátula de gran formato con sombra ambiental suave.
  - Título del disco arriba en tipografía destacada.
  - Autores/artistas debajo con enlace de navegación al perfil del artista.
  - Barra de acciones flotante (Reproducir álbum, Aleatorio, Descargar todo, Guardar en biblioteca).
  - Tracklist secuencial respetando el orden del disco, sin numeración `#` visible por defecto, con micro-indicador activo y menú de acciones por pista.

## Capabilities

### New Capabilities
- `artist-discography`: Consulta de álbumes y discografía oficial del artista mediante YouTube Data API y presentación en cuadrícula interactiva.
- `album-experience`: Vista inmersiva de álbum con cabecera jerárquica (carátula, título arriba, autores abajo), acciones flotantes y tracklist secuencial sin enumerar.

### Modified Capabilities

## Impact

- `DiegoMusic/YouTube/YouTubeEndpoint.swift`: Soporte para endpoints de playlists de canal (`/youtube/v3/playlists`).
- `DiegoMusic/YouTube/YouTubeDataService.swift`: Consulta asíncrona de álbumes del artista y mapeo tipado.
- `DiegoMusic/YouTube/DiscoveryModels.swift`: Actualización de `ArtistDetail` con campo `albums: [Album]`.
- `DiegoMusic/Features/Home/ArtistView.swift`: Integración de la sección de álbumes con navegación a `AlbumView`.
- `DiegoMusic/Features/Home/AlbumView.swift`: Rediseño completo según especificación visual inmersiva.
