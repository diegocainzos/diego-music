# Especificación: artist-album-navigation

## ADDED Requirements

### Requirement: Navegación al Perfil de Artista
El sistema MUST permitir navegar a la vista de perfil de un artista (`ArtistView`) a partir del identificador de canal (`channelID`) o del nombre del artista/canal (`channelTitle`).

#### Scenario: Apertura desde el menú de 3 puntos
- **Given** el usuario despliega el menú contextual de una canción en la búsqueda o biblioteca
- **When** pulsa la opción "Ver artista"
- **Then** se presenta la vista de perfil del artista mostrando sus pistas destacadas y contenidos relacionados.

### Requirement: Navegación al Perfil de Álbum
El sistema MUST permitir navegar a la vista de detalle de un álbum o lista (`AlbumView`) a partir del `playlistID` o título asociado.

#### Scenario: Apertura desde el menú de 3 puntos
- **Given** el usuario despliega el menú contextual de una canción
- **When** pulsa la opción "Ver álbum"
- **Then** se presenta el detalle del álbum/lista mostrando sus pistas y metadatos.
