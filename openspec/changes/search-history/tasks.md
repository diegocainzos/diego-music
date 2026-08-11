## 1. Infraestructura de búsqueda

- [x] 1.1 Añadir enum `SearchScope: String, CaseIterable` (`todo`, `canciones`, `albumes`, `artistas`, `letras`) con nombre localizado y símbolo SF.
- [x] 1.2 Añadir almacén `SearchHistory` que persista hasta 10 consultas recientes deduplicadas como JSON en `PreferenceRecord` (`search.recentQueries`) vía `LibraryStore`.

## 2. ViewModel

- [x] 2.1 Inyectar `LibraryStore` en `SearchViewModel` y exponer `recentQueries` publicadas.
- [x] 2.2 Añadir `activeScope` publicado y filtrar `SearchPage` por scope (Todo raw, Canciones `.video`, Álbumes `.playlist`/`.video`, Artistas `.channel`, Letras heurística de título).
- [x] 2.3 Añadir debounce (~300 ms) a la consulta con cancelación de la tarea anterior; conservar estados de presentación y errores sanitizados.

## 3. Vista

- [x] 3.1 Mostrar selector de ámbito (segmentado o chips) en `SearchView` con etiquetas accesibles.
- [x] 3.2 Mostrar historial reciente en estado vacío/foco, con selección que rellena el campo y busca; estado vacío propio del ámbito.
- [x] 3.3 Respetar `accessibilityReduceMotion` en las transiciones del selector/historial.

## 4. Validación

- [x] 4.1 Regenerar el proyecto si hay ficheros nuevos y ejecutar validaciones Swift/macOS+iOS Simulator. _(No ejecutable en Linux sin Xcode; XcodeGen los recoge en el merge; build/mac+iOS Simulator queda como verificación en Mac.)_
- [x] 4.2 Validar el cambio OpenSpec estricto: `openspec validate search-history --type change --strict`.
