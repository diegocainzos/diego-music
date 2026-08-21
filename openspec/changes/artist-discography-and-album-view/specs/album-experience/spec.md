## ADDED Requirements

### Requirement: Cabecera inmersiva de álbum con jerarquía visual y enlace al artista
La vista `AlbumView` MUST mostrar un encabezado hero con carátula de gran formato, esquinas redondeadas y sombra ambiental, situando el título del álbum en la parte superior y el nombre del artista/autor en la parte inferior como enlace interactivo hacia su perfil.

#### Scenario: Visualización del encabezado del álbum
- **WHEN** el usuario accede a la vista de un álbum cargado exitosamente
- **THEN** se muestra la carátula destacada con sombra ambiental difuminada, el título del disco destacado arriba y el nombre del artista abajo con metadatos asociados (ej. número de canciones)

#### Scenario: Navegación al artista desde el álbum
- **WHEN** el usuario pulsa sobre el nombre del artista en el encabezado del álbum
- **THEN** la aplicación navega hacia la ficha `ArtistView` del artista correspondiente

### Requirement: Barra de acciones flotante para el álbum
La vista `AlbumView` MUST incluir una barra de acciones tipo cápsula con botones para reproducir el álbum completo en orden, reproducción aleatoria, descarga para reproducción offline y guardado en la biblioteca.

#### Scenario: Reproducción del álbum completo
- **WHEN** el usuario pulsa el botón principal de reproducción en la cabecera
- **THEN** el coordinador reproduce la primera pista y encola el resto de pistas del álbum manteniendo la secuencia

### Requirement: Lista de canciones secuencial sin numeración visible
La tabla de canciones de `AlbumView` MUST listar todas las pistas del álbum en el orden estricto del disco (`snippet.position` / orden de entrega de la playlist), omitiendo números de pista explícitos (`#`) y mostrando título, duración, estado de reproducción activa y menú de opciones rápidas por pista.

#### Scenario: Visualización del listado de pistas del álbum
- **WHEN** se presenta la lista de canciones del álbum
- **THEN** cada fila muestra el título de la canción, artista secundario o canal, duración formateada y menú contextual, sin mostrar una columna de numeración `#`

#### Scenario: Pista en reproducción activa
- **WHEN** una pista del álbum coincide con el elemento actual en reproducción de `AVPlayer`
- **THEN** la fila resalta con el color de acento y muestra el indicador visual de reproducción activa
