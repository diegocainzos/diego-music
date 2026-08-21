## 1. YouTube Data API & Data Models

- [x] 1.1 Añadir endpoints para listas de reproducción de canal y búsqueda de álbumes en `YouTubeEndpoint.swift`.
- [x] 1.2 Añadir o actualizar DTOs y mapeos para listas de reproducción (`YouTubePlaylistListResponseDTO`).
- [x] 1.3 Incorporar `albums: [Album]` en la estructura `ArtistDetail` dentro de `DiscoveryModels.swift`.
- [x] 1.4 Implementar la consulta concurrente de álbumes/playlists en `YouTubeDataService.artist(byChannelID:)`.

## 2. Integración en Perfil de Artista (`ArtistView`)

- [x] 2.1 Actualizar la sección de Discografía y Álbumes en `ArtistView.swift` para renderizar `detail.albums`.
- [x] 2.2 Conectar la pulsación de cada tarjeta de álbum con la navegación a `.albumDetail(id: album.id, title: album.title)`.

## 3. Rediseño Inmersivo de `AlbumView`

- [x] 3.1 Rediseñar el encabezado hero con carátula de gran formato, título del álbum arriba y nombre del artista abajo con enlace interactivo.
- [x] 3.2 Diseñar la barra de acciones flotante con reproducción secuencial, aleatoria, descarga offline y guardado en biblioteca.
- [x] 3.3 Implementar el listado secuencial de canciones limpio sin columna `#` de numeración, con indicador de pista activa y menú contextual.

## 4. Pruebas y Validación

- [x] 4.1 Actualizar y añadir pruebas unitarias para `artist(byChannelID:)` y endpoints de playlists.
- [x] 4.2 Validar OpenSpec con `--strict` y compilar el proyecto.
