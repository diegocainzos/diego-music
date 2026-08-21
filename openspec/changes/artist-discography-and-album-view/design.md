## Context

La aplicación cuenta con una pantalla de detalle de artista (`ArtistView`) y de álbum (`AlbumView`). Sin embargo, `ArtistView` actualmente no consulta las listas/álbumes reales del artista en YouTube Data API, sino que reutiliza videos recomendados. Además, `AlbumView` contiene elementos heredados (como la columna `#` de número de pista) y necesita alinearse con la nueva especificación visual inmersiva (título superior, artistas abajo, carátula con sombra ambiental y lista secuencial limpia).

## Goals / Non-Goals

**Goals:**
- Extender `YouTubeEndpoint` con soporte para consulta de playlists de un canal (`/youtube/v3/playlists?channelId=...`) y búsqueda de álbumes (`/youtube/v3/search?type=playlist&q=...`).
- Extender `YouTubeDataService` para consultar de forma concurrente los álbumes oficiales del artista y exponerlos en `ArtistDetail.albums: [Album]`.
- Conectar la sección "Discografía y Álbumes" de `ArtistView` para mostrar los álbumes reales y navegar a `AlbumView` con el ID de la lista.
- Rediseñar `AlbumView` con la jerarquía estética requerida: Carátula de gran formato, título del álbum arriba, artistas abajo con enlace interactivo, barra de acciones y tracklist secuencial sin enumerar.

**Non-Goals:**
- Modificar el sistema de resolución de audio ni endpoints protegidos del VPS.
- Alterar el esquema de base de datos Core Data (las entidades `SavedAlbum` y `LocalAlbum` ya son compatibles con este flujo).

## Decisions

### 1. Consulta de Discografía mediante Concurrencia Estructurada (`async let`)
En `YouTubeDataService.artist(byChannelID:)`, se añadirán llamadas concurrentes:
- Si el ID es un canal (`UC...`), se consulta `/youtube/v3/playlists?channelId=...`.
- Si el canal no tiene playlists o el ID es un nombre, se realiza una búsqueda secundaria tipada con `type=playlist&q="\(artistName) album"`.
- Se mapean los resultados como `Album` y se incluyen en `ArtistDetail`.

### 2. Estructura y Jerarquía Visual de `AlbumView`
- **Encabezado Hero:** Carátula central con sombra ambiental (`shadow(color: ...)`), título arriba en tipografía bold destacada y nombre del artista abajo como botón de navegación a `ArtistView`.
- **Barra de Acciones Flotante:** Contenedor estilizado con botón principal de reproducción circular con acento, modo aleatorio, descarga offline y guardado en biblioteca.
- **Tracklist Secuencial:** Se elimina la cabecera `#` y el número de índice en las filas, manteniendo el orden estricto del disco. Cada fila incluye título, subtítulo con artistas invitados/canal, duración y menú contextual.

## Risks / Trade-offs

- [Cuota de YouTube Data API] → La consulta de playlists consume unidades mínimas (1 unidad por listado). Se integra en la rotación de claves existente (`executeWithRotation`).
- [Artistas sin playlists oficiales en su canal] → Se implementa un fallback transparente que busca playlists por el nombre del artista, asegurando que siempre se muestren lanzamientos válidos.
