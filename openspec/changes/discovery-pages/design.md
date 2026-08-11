## Context

DiegoMusic usa YouTube Data API v3 para catálogo y metadatos (solo snippet), a través de `YouTubeDataService` (protocolo `YouTubeDataServicing`) con un único método `search(query:pageToken:)` que devuelve `SearchPage` (`[MediaItem]` + `nextPageToken`). El transporte `URLSessionTransport` y el cifrado por URL de `YouTubeEndpoint` manejan la `apiKey` internamente y nunca deben loguearse.

`HomeView` es hoy una pantalla estática (hero + tres tarjetas de características). `SearchView` devuelve resultados planos sin navegación a contexto. Para llegar a artista/álbum hace falta: (a) nuevos puntos finales de YouTube (channels, videos, playlistItems) y (b) vistas navegables vía `NavigationStack`. ATENCIÓN DE PROPIEDAD: `SearchView`/`SearchViewModel` los posee otro cambio (`search-history`); este cambio NO edita `SearchView`. La navegación push se implementa SOLO dentro de `HomeView` (que este cambio posee).

## Goals / Non-Goals

**Goals:**

- Convertir Inicio en una pantalla de descubrimiento con una sección "Descubrir / Novedades" poblada por resultados públicos de YouTube.
- Añadir página de artista (top tracks, discografía, relacionados) y página de álbum (lista de pistas).
- Extender la capa de YouTube con métodos async nuevos sin romper `search(query:pageToken:)`.
- Navegar por push desde Inicio sin tocar `RootView` ni `SearchView`. Para permitir alcanzar artista/álbum desde Búsqueda en el futuro, dejar un seam documentado (una celda en `SearchView` que el dueño `search-history` puede cablear tras el merge) sin editarlo aquí.
- Mantener acceso de contraseña (apiKey) y errores sanitizados exactamente como hoy.

**Non-Goals:**

- Recomendaciones basadas en perfil o ML propietario (se usan resultados públicos/curated de YouTube, sin datos de usuario).
- Descarga ni caché de audio; el descubrimiento solo obtiene metadatos.
- Letras, reproducción en otro motor o cambios en `AVPlayer`/cola/resolución.
- Editar `RootView`, `PlayerDock`, persistencia o cualquier fichero ajeno.

## Decisions

### Extender el servicio sin romper la firma existente

Se añaden métodos async nuevos al protocolo `YouTubeDataServicing` y a `YouTubeDataService` (con `default` en protocolo o en extensión para no obligar a que otros conformantes cambien): `artist(byChannelID:)` (perfil + top tracks + relacionados vía `channels`/`videos`) y `album(byPlaylistID:)` (tracks vía `playlistItems`). La firma existente `search(query:pageToken:)` no cambia. Cada retorno usa tipos `Sendable`/`Equatable` nuevos (por ejemplo `Artist`, `Album`, `Track`) mapeados por `YouTubeMapper` desde DTOs nuevos en `YouTubeDTOs.swift`. Los nuevos `YouTubeEndpoint` cases (channels/videos/playlistItems) conservan el patrón actual: `URLComponents` + `key`, `maxResults` acotado, timeout 20s y `Accept: application/json`.

### Navegación por push sin tocar RootView

Solo `HomeView` (poseído por este cambio) envuelve su contenido en `NavigationStack`, de modo que una celda de artista o álbum hace `navigationDestination(for:)` hacia `ArtistView`/`AlbumView` dentro de Home. No se modifica `RootView` (otro cambio) ni `SearchView` (otro cambio). El descubrimiento es autónomo desde Inicio; la integración opcional desde Búsqueda queda como dependencia de merge coordinada con `search-history`.

### Inicio con sección "Descubrir / Novedades"

`HomeView` se apoya en un `HomeViewModel` (`@MainActor`, `ObservableObject`) que lanza una búsqueda/feed público best-effort (por ejemplo un `search` de música sin consulta o un endpoint de novedades) y expone estados cargando/cargado/vacío/error. Se declara explícitamente como contenido público y no personalizado; si falla, Inicio conserva su presentación actual con un estado de error sanitizado y reintento.

## Risks / Trade-offs

- [Descubrimiento depende de cuota/red de YouTube] → se trata como best-effort: estados vacío/error sanitizados y reintento, sin interrumpir el resto de la app.
- [Nuevos métodos rompen conformantes] → se añaden con implementación por defecto para no obligar a cambios en otros conformantes actuales (solo hay `YouTubeDataService`).
- [Página de álbum requiere playlistItems] → el endpoint `playlistItems` devuelve `videoId`+`snippet`; se mapea a `Track`/`MediaItem` reutilizando el patrón de carátula `high`/`medium`/`default`.
- [No diferencia artistas frente a canales publicitarios] → se documenta como limitación honesta; la página de artista agrupa por `channelId`.
- [apiKey en URLs] → el manejo de `YouTubeEndpoint` no cambia: la clave va en el query y nunca se loguea.

## Migration Plan

1. Añadir DTOs nuevos y cases de `YouTubeEndpoint` (channels/videos/playlistItems) con el patrón existente.
2. Ampliar `YouTubeMapper` con mapeos a `Artist`/`Album`/`Track`.
3. Añadir métodos async nuevos al protocolo/servicio (con default) sin tocar `search(query:pageToken:)`.
4. Crear `HomeViewModel` y rehacer `HomeView` con la sección "Descubrir / Novedades".
5. Crear `ArtistView` y `AlbumView` y navegarlas por push desde Home únicamente.
6. Regenerar el proyecto si hay ficheros nuevos, ejecutar validaciones y revisar accesibilidad.

Rollback: revertir el cambio; la capa de búsqueda existente y la reproducción no se tocan.

## Open Questions

- Confirmar en dispositivo si el endpoint de "novedades" elegido respeta categoría música y cuota (posible ajuste de `videoCategoryId`).
- Decidir si la página de álbum debe agrupar por listas existentes o solo por `playlistId` proveniente de búsqueda.
