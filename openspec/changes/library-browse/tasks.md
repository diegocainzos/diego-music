## 1. Modelo y store

- [ ] 1.1 Ampliar `LibraryStore` con `rename(_:to:)` para playlists (crear/borrar/reordenar ya existen).
- [ ] 1.2 Añadir agrupadores derivados (Canciones/Álbumes/Artistas/Listas) a partir de favoritos e historial; añadir/ajustar atributos en `LibraryModels`/`PersistenceController` solo si hace falta álbum (atributo opcional + migración automática).

## 2. Vistas de biblioteca

- [ ] 2.1 Crear `SongsView`, `AlbumsView`, `ArtistsView` y `ListaView` bajo `DiegoMusic/Features/Library/` usando el sistema de diseño vigente (`DiegoTheme`, `SectionHeader`, `EmptyStateView`, `minimalCard`).
- [ ] 2.2 Reestructurar `LibraryView` como contenedor con sub-pestañas y gestión guardar/quitar (corazón).

## 3. Búsqueda local

- [ ] 3.1 Implementar filtro de búsqueda local por título, artista y álbum en las colecciones derivadas, con estado vacío.

## 4. Corazón y recomendaciones

- [ ] 4.1 Derivar el listado "Me gusta" de los favoritos y una heurística local de recomendaciones (frecuencia de artistas/historia común) sin red.

## 5. Integración y validación

- [ ] 5.1 Cablear las sub-pestañas/páginas en `RootView` sin tocar `PlayerDock`.
- [ ] 5.2 Regenerar el proyecto si hay ficheros nuevos y ejecutar validaciones (validate.sh + xcodebuild en macOS/Xcode; en este host Linux solo openspec CLI).
- [ ] 5.3 Revisar que la accesibilidad (labels, foco, contraste, reduce-motion) se conserva en todas las vistas nuevas.
