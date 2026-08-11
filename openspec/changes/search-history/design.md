## Context

`SearchView` usa `SearchViewModel`, un `ObservableObject` que ejecuta una única búsqueda en `YouTubeDataService` (protocolo `YouTubeDataServicing`). Cada resultado es un `MediaItem` con `kind` (`video`, `channel`, `playlist`), `title` y `channelTitle`. El modelo de datos local de DiegoMusic (Core Data) ya expone `PreferenceRecord` (clave/valor) a través de `LibraryStore.preference(for:)/setPreference(_:for:)`, hoy usado por `PlaybackSettings` para el flag de historial. `SearchViewModel` no tiene acceso a `LibraryStore` en el momento; `SearchView` sí recibe `library: LibraryStore`.

## Goals / Non-Goals

**Goals:**

- Recordar las últimas consultas de búsqueda del usuario de forma local y mostrarlas al enfocar/vacío.
- Ofrecer un selector de ámbito (Todo/Canciones/Álbumes/Artistas/Letras) que filtra los resultados en el cliente.
- Debounce, cancelación de tareas y errores sanitizados.
- Mantener las etiquetas de accesibilidad y `accessibilityReduceMotion`.

**Non-Goals:**

- Añadir búsqueda semántica real de letras ni integración con una base de datos de letras (no existe índice; «Letras» es un filtro visual best-effort).
- Modificar `YouTubeDataService`, `YouTubeDTOs`, `YouTubeEndpoint` ni `YouTubeMapper` (los posee el cambio `discovery-pages`).
- Tocar cola/AVPlayer, `RootView`, `LibraryView` ni `PlayerDock` (otros cambios los poseen).
- Añadir modelos Core Data nuevos ni migraciones.

## Decisions

### Historial reciente persistido en `PreferenceRecord`

Se añade un almacén ligero `SearchHistory` (nuevo fichero en `DiegoMusic/Features/Search/`) que serializa una lista ordenada de consultas (≤ 10, más reciente primero, sin duplicados) como JSON en una clave única (`search.recentQueries`) mediante la API `PreferenceRecord` existente de `LibraryStore`. Necesita una inyección del `LibraryStore` en `SearchView`/`SearchViewModel`. Al completar una búsqueda con éxito con una consulta no vacía, se inserta la consulta (nueva consulta al frente, deduplicada). Al enfocar el campo o con `query` vacía se muestran las consultas recientes.

Alternativa descartada: entidad Core Data nueva `RecentSearch`. Añade un modelo y migración para guardar cadenas; `PreferenceRecord` cubre el caso sin romper la persistencia existente.

### Selector de ámbito (scope) filtra en el cliente

Nuevo enum `SearchScope: String, CaseIterable` con `todo`, `canciones`, `albumes`, `artistas`, `letras`. `SearchViewModel` guarda el scope activo y, al recibir `SearchPage`, filtra `items` según:
- `canciones` → `kind == .video`.
- `artistas` → `kind == .channel`.
- `albumes` → `kind == .playlist` (o `.video` con indicación de álbum; best-effort).
- `letras` → filtro visual honesto sobre `title`/`channelTitle` (coincidencia de consulta); no promete matching semántico de texto de letras.
- `todo` → sin filtrar.

La petición de red se lanza una sola vez con la consulta; el scope solo refina la presentación, sin llamadas adicionales. Si el filtrado deja vacío el resultado se muestra el estado vacío correspondiente.

### Debounce y cancelación

`SearchViewModel` añade un debounce (por ejemplo 300 ms) al cambiar `query`, con cancelación de la tarea anterior (`searchTask?.cancel()`), reutilizando el patrón actual. Los estados de presentación existentes (`idle/loading/loaded/empty/failed`) se conservan y se añade el historial reciente como parte del estado vacío/foco.

### Errores sanitizados y accesibilidad

Los mensajes de error siguen usando `LocalizedError.errorDescription` con respaldo en español, sin incorporar excepciones crudas de red/HTTP. Los controles del selector y de historial llevan etiquetas accesibles; las transiciones de scope respetan `accessibilityReduceMotion`.

## Risks / Trade-offs

- [Selector «Letras» sugiere búsqueda de letras que no existe] → la spec y la UI lo presentan como filtro visual best-effort («canciones cuya coincidencia parece de letra»), sin prometer matching semántico.
- [Peticiones duplicadas por debounce mal configurado] → debounce con cancelación de la tarea anterior y validación de no-vacío.
- [Historial crece o duplica] → límite de 10 entradas deduplicadas, más reciente al frente.
- [Filtrado deja resultados vacíos] → estado vacío por scope, distinto de «sin resultados en YouTube».
- [Dependencia con cambio `discovery-pages` que posee la capa YouTube] → este cambio usa solo `YouTubeDataServicing` tal cual, sin editarlo.

## Migration Plan

1. Añadir enum `SearchScope` y almacén `SearchHistory` (nuevos ficheros).
2. Inyectar `LibraryStore` en `SearchView`/`SearchViewModel` y exponer consultas recientes.
3. Filtrar resultados por scope en `SearchViewModel`.
4. Añadir selector de scope y lista de historial en `SearchView` con accesibilidad.
5. Regenerar el proyecto si hay ficheros nuevos y ejecutar validaciones.

Rollback: revertir `SearchViewModel`/`SearchView` y ficheros nuevos; la búsqueda base queda intacta.

## Open Questions

- Verificar en dispositivo si el filtro «Letras» ofrece valor real o conviene ocultarlo tras una configuración.
- Decidir si el historial debe poder borrarse de forma individual (fuera de alcance por ahora; solo seguirá el borrado global de historial existente).
