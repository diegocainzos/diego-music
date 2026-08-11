## Why

La búsqueda global de DiegoMusic funciona (una consulta, una petición a YouTube Data API) pero no conserva ningún contexto: cada visita a la sección arranca en blanco, no hay historial reciente y no hay forma de acotar qué se busca (canción, artista, álbum o letra). Para una experiencia cercana a un reproductor moderno, el usuario espera recuperar búsquedas recientes y poder filtrar el resultado.

## What Changes

- Persistir localmente las búsquedas recientes del usuario (consultas completadas con éxito) y mostrarlas al enfocar el campo de búsqueda o cuando no hay consulta.
- Añadir un selector de ámbito (scope): **Todo / Canciones / Álbumes / Artistas / Letras** que filtra el mismo conjunto de resultados devueltos por YouTube según `MediaItem.kind` y el título, sin lanzar peticiones adicionales.
- Especificar «Letras» de forma honesta como un filtro visual best-effort: DiegoMusic no tiene índice de letras, por lo que el filtro reduce por título/consulta sin prometer búsqueda semántica de texto de letras.
- Debounce de la consulta, cancelación de tareas de red y mensajes de error sanitizados (sin excepciones crudas de red/HTTP).

## Capabilities

### New Capabilities

- `search-history`: historial reciente de búsquedas persistido localmente y selector de ámbito de búsqueda (Todo/Canciones/Álbumes/Artistas/Letras) que filtra los resultados de YouTube en el cliente.

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ no existe aún). `search-history` es un delta ADDED; no modifica capabilities archivadas. -->

## Impact

- Cliente: `SearchViewModel`, `SearchView` y nuevos ficheros bajo `DiegoMusic/Features/Search/` (almacén de historial por `PreferenceRecord` y enum de scope).
- Comportamiento: la sección de búsqueda recuerda consultas recientes y permite filtrar resultados por tipo.
- Sin cambios en `YouTubeDataService`/capa YouTube (otro cambio la posee), ni en `ResolverService`, persistencia de cola/AVPlayer ni otras vistas.
- La accesibilidad existente (labels, reduce motion) se conserva y se explicita en el nuevo spec.
