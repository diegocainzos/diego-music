# Cambio: Menú contextual de 3 puntos en filas de búsqueda

## Why

En la pantalla de búsqueda, cada canción (`SearchResultRow`) requiere un menú de acciones completo mediante un botón de 3 puntos (`ellipsis`). El usuario debe poder realizar acciones comunes como añadir una canción a la cola en primer lugar (play next / enqueue top), añadir a playlist, ir al perfil del artista o ir al detalle del álbum directamente desde los resultados de búsqueda.

## What Changes

- **Menú contextual de 3 puntos en `SearchResultRow`**: reemplazar o expandir el menú actual para incluir:
  1. **Añadir a la cola (al principio)**: encola el tema inmediatamente después de la pista actual en `PlaybackQueue`.
  2. **Añadir a playlist**: submenú o diálogo para agregar la canción a una playlist existente de la biblioteca.
  3. **Ir al artista**: navega o presenta la vista de detalle del artista (`ArtistView`) para la pista.
  4. **Ir al álbum**: navega o busca la información del álbum asociado a la pista.
- **Callback / Enrutado de acciones**: la vista de búsqueda expone handlers de navegación para artista y álbum hacia las vistas correspondientes.

## Capabilities

### New Capabilities

- `search-track-actions`: menú contextual de 3 puntos en resultados de búsqueda con acciones directas para encolar al principio, añadir a playlist, navegar al perfil de artista y navegar a álbum.

### Modified Capabilities

<!-- No hay baseline archivado. -->

## Impact

- Cliente Swift: `DiegoMusic/Features/Search/SearchView.swift` (SearchResultRow y menú contextual), `DiegoMusic/Core/Models/PlaybackQueue.swift` (método para encolar en primera posición / enqueueNext), `DiegoMusic/App/RootView.swift` (enrutado a vistas de artista/álbum).
