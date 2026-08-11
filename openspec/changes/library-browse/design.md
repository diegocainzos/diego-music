## Context

DiegoMusic almacena la colección del usuario en Core Data: favoritos (`FavoriteTrackRecord`), playlists (`PlaylistRecord` + `PlaylistEntryRecord`), historial de reproducción (`PlaybackHistoryRecord`) y preferencias (`PreferenceRecord`), gestionados por `LibraryStore` y con el modelo creado en `PersistenceController`. Hoy `LibraryView` muestra únicamente la lista de favoritos y `PlaylistsView` gestiona las listas (crear, borrar, reordenar elementos); falta renombrar. No existe aún búsqueda local, vistas agrupadas (Canciones/Álbumes/Artistas/Listas) ni recomendaciones locales.

## Goals / Non-Goals

**Goals:**

- Convertir la Biblioteca en una colección local explorable: Canciones, Álbumes, Artistas y Listas, agrupadas a partir de los registros locales.
- Ofrecer búsqueda **dentro de tu biblioteca** (título, artista, álbum local) filtrando las colecciones derivadas.
- Completar la gestión de playlists incluyendo el renombrado y el listado automático "Me gusta".
- Mantener guardar/quitar canciones reutilizando los favoritos existentes.
- Añadir una heurística local de recomendaciones basada en favoritos (sin red).
- Cablear las nuevas sub-pestañas en `RootView` sin modificar `PlayerDock`.

**Non-Goals:**

- Hacer llamadas nuevas a YouTube para derivar álbumes/artistas (todo es local).
- Migrar Core Data a SwiftData.
- Cambiar el modelo de datos de reproducción, el resolutor o la reproducción.
- Modificar `PlayerDock` ni `AudioPlayerCoordinator` (pertenecen a otros cambios).
- Implementar recomendaciones basadas en perfiles de usuario ni personalización por red.

## Decisions

### Vistas agrupadas derivadas de registros locales

`LibraryView` se convierte en un contenedor con sub-pestañas/páginas: Canciones (favoritos), Álbumes (agrupados por álbum si existe el dato, o derivados de favoritos), Artistas (agrupados por `channelTitle` de favoritos/historial) y Listas (las playlists). Los agrupadores se computan en memoria a partir de `LibraryStore` (favoritos, historial) sin nuevas propiedades de red. Toda la navegación nueva vive en `DiegoMusic/Features/Library/` (datos `SongsView`/`AlbumsView`/`ArtistsView`/`ListaView`); `RootView` solo pasa la pestaña correspondiente. `PlayerDock` no se toca.

Alternativa descartada: pedir álbumes/artistas a YouTube. Contradice el alcance local y añade dependencia de red para una operación de colección.

### Búsqueda local por título, artista y álbum

Un estado de búsqueda por consulta filtra en cliente los elementos de cada vista (Canción/Arista/Álbum/Lista) comparando título y `channelTitle` (y el álbum cuando esté disponible). Es local e instantáneo; no consume cuota de YouTube. Se respeta el teclado (foco) y se mantienen etiquetas accesibles.

### Gestión completa de playlists (incluye renombrar)

Se añade un método `rename(_:to:)` en `LibraryStore` sobre `PlaylistRecord.name`, y la UI de listas expone crear, renombrar, borrar y reordenar elementos (reordenar ya existe). "Me gusta" es una playlist automática / sección derivada de favoritos con corazón, construida localmente.

### Corazón y recomendaciones heurísticas locales

El corazón ("Me gusta") se deriva de los favoritos existentes (ya se mantiene con `toggleFavorite`). Las recomendaciones usan una heurística simple y local: canciones favoritas del mismo artista / con ligas comunes en el historial, priorizadas por frecuencia; sin red ni perfil de servidor.

### Persistencia sigue en Core Data

No se migra a SwiftData. Si se añade un campo nuevo (p. ej. álbum) en `LibraryModels`/`PersistenceController`, se mantiene un modelo compatible y migración automática (`shouldMigrateStoreAutomatically` ya activo). El alcance preferido es derivar sin tocar el esquema; solo si hace falta álbum se añade atributo opcional.

### Accesibilidad preservada

Las nuevas vistas reutilizan el sistema de diseño vigente (`DiegoTheme`, `SectionHeader`, `EmptyStateView`, `minimalCard`) y conservan etiquetas accesibles, foco de teclado, áreas táctiles ≥ 44pt y `accessibilityReduceMotion`.

## Risks / Trade-offs

- [Álbumes derivados imprecisos sin dato de álbum en favoritos] → derivar de forma conservadora (agrupar por artista o por título si no hay álbum); documentar el límite.
- [Dependencia con el sistema de diseño / reproducción en otros cambios] → este cambio solo consume la API de diseño y reproducción existentes; no edita `PlayerDock` ni `AudioPlayerCoordinator`.
- [Renombrar o recomendar rompen build] → `LibraryStore` y modelos se extienden con métodos testables; la validación (`validate.sh`, `xcodebuild test`) se ejecuta en macOS con Xcode (este host Linux sin Xcode no puede compilar; solo se valida el cambio con openspec CLI).
- [Recomendaciones heurísticas simples decepcionan] → se enmarcan como locales y experimentales; mejorar con datos de red queda fuera de alcance.

## Migration Plan

1. Ampliar `LibraryStore` con `rename(_:to:)` y (si procede) agrupadores derivados; añadir/ajustar modelos solo si hace falta álbum.
2. Crear las vistas nuevas `SongsView`/`AlbumsView`/`ArtistsView`/`ListaView` (ficheros nuevos bajo `DiegoMusic/Features/Library/`; XcodeGen los incluye).
3. Reestructurar `LibraryView` con sub-pestañas y búsqueda local.
4. Cablear las sub-pestañas en `RootView` (solo la sección Biblioteca; no tocar `PlayerDock`).
5. Regenerar el proyecto si hay ficheros nuevos y validar (validate.sh + xcodebuild en macOS).

Rollback: revertir el cambio; favoritos/playlists e historial existentes permanecen intactos.

## Open Questions

- ¿Se requiere un atributo `album` real o basta derivar Álbumes de favoritos/historial? (Se asume derivación sin tocar esquema; añadir atributo opcional solo si la UI lo exige).
