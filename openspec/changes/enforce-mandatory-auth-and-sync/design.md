## Context

DiegoMusic funcionaba con un modelo híbrido en el que la app permitía uso local anónimo sin autenticación, mientras contaba paralelamente con endpoints de autenticación y datos de usuario en un backend FastAPI. Esta duplicidad de modelo causaba desincronización y colapso de estado:
1. Core Data guardaba favoritos, listas e historial localmente sin ID de usuario.
2. Al iniciar sesión, la app no subía ni descargaba completamente los favoritos ni el historial de reproducciones, ni sincronizaba las pistas individuales dentro de las playlists.
3. Al cerrar sesión o cambiar de cuenta, Core Data mantenía los registros del usuario anterior o del uso local anónimo.
4. El backend FastAPI requería `track_id` como un `Int` relacional, mientras que el cliente de iOS manejaba `videoID` de YouTube como un `String` alfanumérico, lo que provocaba que la conversión `Int(item.id)` fallara y la API de historial y favoritos fuera inalcanzable.
5. Las contraseñas en el registro solo requerían un mínimo de 6 caracteres sin reglas de complejidad.

## Goals / Non-Goals

**Goals:**
- Convertir la aplicación en 100% dependiente de inicio de sesión (`AuthGateView` en la raíz).
- Imponer la regla de contraseña: entre 10 y 25 caracteres, y al menos una letra mayúscula (validado en Swift UI y en FastAPI Pydantic schema).
- Crear un puente en el backend FastAPI para que las peticiones de favoritos, playlists e historial acepten y resuelvan el `youtube_video_id` (string), creando el registro en `tracks` dinámicamente si no existiera previamente.
- Aislamiento de sesión en Core Data: purgar todas las entidades locales al cerrar sesión y al iniciar sesión antes de rellenar la caché con la colección del usuario autenticado.
- Sincronización bidireccional completa y en tiempo real de Playlists (creación, renombramiento, adición/eliminación de canciones, orden), Favoritos y Historial de reproducción.

**Non-Goals:**
- Reemplazar Core Data por SwiftData (se mantiene Core Data según las reglas de AGENTS.md).
- Permitir reproducción sin conexión para usuarios no autenticados (las descargas offline requerirán también estar autenticado).
- Implementar login social OAuth (Google/Apple) en esta fase (se mantiene autenticación por correo/contraseña).

## Decisions

### 1. `AuthGateView` como Puerta de Entrada en `RootView`
- **Decisión:** En lugar de presentar la interfaz principal con un botón "Sign In" secundario, `RootView` evaluará `environment.authState`:
  - `.loading`: Muestra un spinner / splash de carga limpio.
  - `.unauthenticated`: Renderiza `AuthGateView` (sin botón de cancelar o descartar modal).
  - `.authenticated(user)`: Renderiza la vista principal (`phoneTabView` / `desktopLayout`).
- **Alternativa considerada:** Presentar un modal `.sheet(isPresented:)` sobre la interfaz principal. *Rechazada:* El usuario aún podía interactuar con la app de fondo o ver datos locales stale.

### 2. Validación de Contraseña en Dos Capas
- **Swift Client (`SignUpView`):**
  - Propiedad computada `isPasswordValid`: `(10...25).contains(password.count) && password.contains(where: \.isUppercase)`
  - Deshabilita el botón de submit e informa los requisitos no cumplidos en vivo.
- **FastAPI Backend (`app/schemas.py` en `UserCreate`):**
  - `@field_validator("password")`: Comprueba `10 <= len(v) <= 25` y `any(c.isupper() for c in v)`.
  - En caso de incumplimiento, retorna HTTP 422 Unprocessable Entity con detalle sanitizado.

### 3. Modificación del Backend para el Puente `youtube_video_id`
- **Decisión:** En `app/schemas.py` y los routers `users.py` y `playlists.py`:
  - `PlayHistoryCreate`, `FavoriteCreate`, `PlaylistTrackAdd` aceptarán opcionalmente `youtube_video_id: str` y metadatos básicos (`title`, `channel_title`, `thumbnail_url`, `duration_seconds`).
  - El backend buscará si existe una pista con dicho `youtube_video_id` en la tabla `tracks`. Si no existe, creará un registro sintético de `Track` (asociado a un artista/álbum por defecto si procede) y usará su `id` interno.
- **Razón:** Elimina la incompatibilidad entre la clave entera de SQL y las cadenas de YouTube Data API v3 sin romper el esquema de base de datos relacional.

### 4. Aislamiento y Ciclo de Vida de Core Data
- **Decisión:** En `AppEnvironment.swift`:
  - Al ejecutar `logout()`: Se borra el token de Keychain, se llama a `library.clearAllUserData()` que borra todos los `FavoriteTrackRecord`, `PlaylistRecord`, `PlaylistEntryRecord`, `PlaybackHistoryRecord` y `SavedAlbumRecord` de Core Data.
  - Al ejecutar `checkInitialAuthState()` o `login()` con éxito: Se limpia Core Data primero y se invoca `syncAllUserDataWithBackend()`.

### 5. Sincronización Completa de Actividad (`syncAllUserDataWithBackend`)
- **Flow de Sincronización al Autenticarse:**
  1. `GET /users/me/favorites`: Descarga todos los favoritos remotos y los escribe en Core Data.
  2. `GET /api/v1/playlists/me`: Para cada playlist devuelta, descarga `GET /api/v1/playlists/{id}` con sus tracks y las guarda en Core Data.
  3. `GET /users/me/history`: Descarga las reproducciones recientes y las guarda en Core Data.
- **Flow de Actualizaciones en Tiempo Real:**
  - `toggleFavorite`: Modifica Core Data y dispara `POST/DELETE /users/me/favorites`.
  - `addTrackToPlaylist`: Modifica Core Data y dispara `POST /api/v1/playlists/{id}/tracks`.
  - `play`: Al iniciar una canción, llama a `POST /users/me/history`.

## Risks / Trade-offs

- **[Riesgo] Latencia en la primera sincronización al iniciar sesión.**
  - *Mitigación:* Ejecutar la sincronización de fondo con `ProgressView` de estado e informar al usuario en caso de error de red.
- **[Riesgo] Contraseñas existentes en entornos de desarrollo/testing con menos de 10 caracteres.**
  - *Mitigación:* Actualizar los scripts de test y la base de datos de test (`test_backend_auth.py`, datos semilla) para usar la contraseña válida por defecto `Password1234`.

## Migration Plan

1. Actualizar esquemas de Pydantic y routers en FastAPI para validación de contraseña y soporte de `youtube_video_id`.
2. Actualizar las pruebas del backend en pytest.
3. Implementar `clearAllUserData()` en `LibraryStore.swift` y `BackendAPIClient.swift` con los endpoints de sincronización total.
4. Crear la vista `AuthGateView.swift` y actualizar `RootView.swift` para alternar la UI según `authState`.
5. Ejecutar suites de prueba en Python y Xcode.
