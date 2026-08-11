# Tareas — Navegación a Perfil de Artista y Álbum

## 1. Estado y Presentación de Navegación

- [x] 1.1 Definir el modelo de destino de presentación modal / sheet (`SearchDetailDestination`) accesible en la jerarquía de vistas.
- [x] 1.2 Añadir modificador `.sheet(item:)` o `navigationDestination` para renderizar `ArtistView` y `AlbumView` dentro de un `NavigationStack`.

## 2. Integración en Menú Contextual de Canciones

- [x] 2.1 Actualizar el menú contextual de 3 puntos en `SearchResultRow` para incluir los botones "Ir al artista" y "Ir al álbum".
- [x] 2.2 Conectar las acciones para que desencadenen la apertura del sheet correspondiente.

## 3. Validación

- [x] 3.1 Ejecutar validación de OpenSpec (`openspec validate artist-album-navigation --type change --strict`).
- [x] 3.2 Verificar compilación y pruebas Swift con `./scripts/validate.sh`.
