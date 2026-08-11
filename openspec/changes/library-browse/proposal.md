## Why

DiegoMusic guarda favoritos y playlists localmente (Core Data), pero la sección Biblioteca solo muestra la lista de favoritos y las listas se gestionan en una pestaña aparte. El usuario no puede explorar su colección por Canciones, Álbumes o Artistas, buscar dentro de ella, renombrar playlists, ni construir listas automáticas a partir de un "Me gusta". Para un cliente de streaming local, la biblioteca es el corazón: necesita vistas de agrupación, búsqueda local y gestión completa de listas para ser útil sin depender del catálogo público.

## What Changes

- Añadir **vistas de biblioteca** Canciones, Álbumes, Artistas y Listas dentro de la sección Biblioteca, agrupando los registros locales existentes (favoritos e historial) con datos **solo locales** (Core Data), sin llamadas nuevas a YouTube.
- Mantener **guardar / quitar canciones** ("biblioteca") reutilizando los favoritos y exponerlo en las nuevas vistas.
- Añadir **búsqueda dentro de tu biblioteca**: filtrar por título de canción, artista y álbum local.
- Completar la gestión de **listas de reproducción**: crear, **renombrar** (hoy falta), borrar y reordenar elementos.
- Añadir el **corazón ("Me gusta")** como listado automático y una **heurística local de recomendaciones** basada en favoritos (sin red).
- Cablear las nuevas sub-pestañas/páginas en `RootView` **sin tocar** `PlayerDock` (perteneciente a otro cambio).

## Capabilities

### New Capabilities

- `library-browse`: biblioteca local navegable por Canciones/Álbumes/Artistas/Listas con búsqueda local, renombrado de playlists, listado "Me gusta" y recomendaciones heurísticas locales (solo Core Data, sin red).

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ no existe aún). `native-audio-playback` y `minimal-apple-music-aesthetic` viven como deltas en cambios en curso; este cambio amplía la capa de persistencia local y las vistas de Biblioteca sin alterar la reproducción ni el sistema de diseño. -->

## Impact

- Cliente: `LibraryStore`, `LibraryModels`, `PersistenceController`, `LibraryView`, `RootView` y nuevos ficheros bajo `DiegoMusic/Features/Library/`.
- Comportamiento: la Biblioteca pasa de "lista de favoritos" a una colección explorable (Canciones/Álbumes/Artistas/Listas) con búsqueda local, renombrado de listas y recomendaciones locales.
- Sin cambios en el resolutor, la API de YouTube, la reproducción/cola, `PlayerDock` ni el sistema de diseño.
- La persistencia sigue siendo Core Data (deliberada); no se migra a SwiftData.
