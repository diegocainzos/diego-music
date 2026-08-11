## ADDED Requirements

### Requirement: Menú contextual de 3 puntos en resultados de búsqueda

Cada fila de resultado de búsqueda `SearchResultRow` SHALL incluir un menú contextual activado por un botón de 3 puntos (`ellipsis`) que contenga las opciones "Añadir a la cola", "Añadir a playlist", "Ir al artista" e "Ir al álbum".

#### Scenario: Botón de 3 puntos
- **WHEN** el usuario visualiza una fila de canción en la búsqueda
- **THEN** se muestra el icono `ellipsis` para desplegar el menú de opciones

#### Scenario: Añadir a la cola al principio
- **WHEN** el usuario selecciona "Añadir a la cola" en el menú
- **THEN** la canción se encola en `PlaybackQueue` inmediatamente después de la pista actual (play next)

#### Scenario: Navegación al artista desde el menú
- **WHEN** el usuario selecciona "Ir al artista" en el menú
- **THEN** la app presenta el detalle del artista (`ArtistView`) correspondiente a `item.channelTitle`

#### Scenario: Navegación al álbum desde el menú
- **WHEN** el usuario selecciona "Ir al álbum" en el menú
- **THEN** la app navega o busca el detalle del álbum asociado
