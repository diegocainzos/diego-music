# Design — Menú contextual de 3 puntos en filas de búsqueda

## Context

Actualmente `SearchResultRow` en `SearchView.swift` incluye botones directos para reproducir y dar a favorito, más un menú básico para añadir a playlist. Se requiere unificar las acciones en un menú contextual limpio de 3 puntos (`ellipsis`) que permita:
1. Encolar a continuación (al principio de la cola).
2. Añadir a playlist.
3. Navegar al perfil del artista (`ArtistView`).
4. Navegar al detalle del álbum (`AlbumView` o búsqueda de álbum).

## Goals / Non-Goals

**Goals**:
- Proveer un menú de 3 puntos accesible e intuitivo en cada `SearchResultRow`.
- Permitir "Añadir a la cola" colocando la canción inmediatamente después de la canción que está sonando.
- Permitir navegar al artista y álbum correspondientes desde el propio menú.

**Non-Goals**:
- No cambiar la arquitectura de audio ni la persistencia de playlists.
- No alterar las operaciones básicas de reproducción directa al tocar la carátula o el título.

## Decisions

### D1. Menú `Menu` de SwiftUI con icono `ellipsis`
Usar la vista `Menu` nativa de SwiftUI para el botón de 3 puntos (`ellipsis`), mostrando opciones con iconos SF Symbols legibles:
- `line.horizontal.3.decrease.circle` / `list.bullet.indent` para "Añadir a la cola"
- `plus.circle` para "Añadir a playlist"
- `person.crop.circle` para "Ir al artista"
- `disc` / `square.stack` para "Ir al álbum"

### D2. Encolado prioritario en `PlaybackQueue` (`enqueueNext`)
Añadir o reutilizar `enqueueNext(_ item: MediaItem)` en `PlaybackQueue` para insertar el tema seleccionado justo después del `currentIndex` actual (o en la posición 0 si no hay reproducción activa).

### D3. Handlers de navegación en `SearchView`
Pasar cierres/callbacks opcionales o bindings a `SearchView` (`onSelectArtist: (String) -> Void`, `onSelectAlbum: (String) -> Void`) para delegar la presentación de `ArtistView` o `AlbumView` al contenedor principal.

## Risks / Trade-offs

- [La pista no tiene un `channelId` completo] → Mitigación: navegar buscando el artista por nombre (`item.channelTitle`) si no se dispone de un ID específico.
