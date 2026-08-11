## 1. Capa de YouTube ampliada

- [ ] 1.1 Añadir DTOs nuevos en `YouTubeDTOs.swift` para canales, vídeos y `playlistItems` (perfil de canal, tracks de álbum, relacionados).
- [ ] 1.2 Ampliar `YouTubeEndpoint` con cases `channels`/`videos`/`playlistItems` siguiendo el patrón actual (`URLComponents` + `key`, `maxResults` acotado, timeout 20s, `Accept: application/json`, nunca loguear la URL ni la clave).
- [ ] 1.3 Ampliar `YouTubeMapper` con mapeos a `Artist`, `Album` y `Track` reutilizando la resolución de carátulas `high`/`medium`/`default`.

## 2. Servicio

- [ ] 2.1 Añadir métodos async nuevos al protocolo `YouTubeDataServicing` y a `YouTubeDataService` (con implementation por defecto) para artista y álbum, sin cambiar la firma `search(query:pageToken:)`.
- [ ] 2.2 Asegurar errores `LocalizedError` sanitizados y retorno de tipos `Sendable`/`Equatable`.

## 3. Descubrimiento en Inicio

- [ ] 3.1 Crear `HomeViewModel` (`@MainActor`, `ObservableObject`) con feed público best-effort y estados carga/vacío/error/reintento.
- [ ] 3.2 Rehacer `HomeView` con la sección "Descubrir / Novedades" conservando el estilo minimal y la accesibilidad.

## 4. Páginas de artista y álbum

- [ ] 4.1 Crear `ArtistView` (perfil, top tracks, discografía, relacionados).
- [ ] 4.2 Crear `AlbumView` (lista de pistas).
- [ ] 4.3 Navegar por push (`NavigationStack` + `navigationDestination`) desde Inicio únicamente, sin tocar `RootView` ni `SearchView` (este último lo posee el cambio `search-history`).

## 5. Validación

- [ ] 5.1 Regenerar el proyecto si hay ficheros nuevos y ejecutar validaciones Swift/macOS+iOS Simulator.
- [ ] 5.2 Validar el cambio OpenSpec estricto y revisar que la accesibilidad no se ha perdido.
