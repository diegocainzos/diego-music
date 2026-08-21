## ADDED Requirements

### Requirement: Consulta de álbumes y playlists del artista
El servicio de catálogo `YouTubeDataService` MUST consultar y recuperar las listas/álbumes oficiales del canal del artista mediante YouTube Data API (`kind: .playlists(channelID:)` o búsqueda tipada de playlists), mapeándolas a estructuras `Album`.

#### Scenario: Carga exitosa de discografía del artista
- **WHEN** el usuario navega a la ficha de un artista con identificador de canal (`channelID`) o nombre
- **THEN** el servicio realiza la consulta de playlists/álbumes asociados y retorna un array `[Album]` con títulos, carátulas y `playlistID`

#### Scenario: Fallback cuando el canal no tiene playlists públicas
- **WHEN** la consulta de playlists del canal no retorna resultados o falla
- **THEN** el servicio realiza una búsqueda secundaria por nombre del artista (`"\(artistName) album"`) o utiliza las recomendaciones existentes sin romper la carga del perfil

### Requirement: Cuadrícula interactiva de discografía en perfil de artista
La vista `ArtistView` MUST presentar una sección dedicada de "Discografía y Álbumes" que muestre las carátulas, títulos y tipo de lanzamiento de los álbumes obtenidos, permitiendo navegar directamente al detalle del álbum seleccionado.

#### Scenario: Selección de un álbum en el perfil del artista
- **WHEN** el usuario pulsa sobre una tarjeta de álbum en la sección de discografía
- **THEN** la aplicación navega a `AlbumView` pasando el `playlistID` y título del álbum seleccionado
