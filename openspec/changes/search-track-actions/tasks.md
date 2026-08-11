# Tareas — Menú contextual de 3 puntos en filas de búsqueda

## 1. Métodos de encolado en PlaybackQueue

- [x] 1.1 Verificar/añadir `enqueueNext(_ item: MediaItem)` en `DiegoMusic/Core/Models/PlaybackQueue.swift` para colocar la pista justo después del índice activo.

## 2. Menú de 3 puntos en SearchResultRow

- [x] 2.1 En `DiegoMusic/Features/Search/SearchView.swift`, actualizar el botón `ellipsis` en `SearchResultRow` para incluir el menú con las 4 opciones:
  - "Añadir a la cola"
  - "Añadir a playlist"
  - "Ir al artista"
  - "Ir al álbum"
- [x] 2.2 Conectar callbacks de navegación `onSelectArtist` y `onSelectAlbum` en `SearchView`.

## 3. Validación

- [x] 3.1 Ejecutar validación de OpenSpec (`openspec validate search-track-actions --type change --strict`).
- [x] 3.2 Compilar y verificar tests con `./scripts/validate.sh`.
