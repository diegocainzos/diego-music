## 1. Backend FastAPI Updates (Password Security & YouTube Video ID Bridge)

- [x] 1.1 Actualizar `app/schemas.py` en `UserCreate` para validar contraseñas de 10 a 25 caracteres y al menos una mayúscula mediante Pydantic `@field_validator`.
- [x] 1.2 Actualizar esquemas Pydantic y routers (`users.py`, `playlists.py`) para aceptar `youtube_video_id` en favoritos, historial y añadir canción a playlist, creando automáticamente registros en `Track` cuando sea necesario.
- [x] 1.3 Actualizar tests de backend `tests/test_backend_auth.py` y fixture de usuarios para usar contraseñas válidas de prueba (`Password1234`).
- [x] 1.4 Validar backend ejecutando `pytest` / `./scripts/validate-resolver.sh`.

## 2. Swift Client Authentication Gate & Password Rules

- [x] 2.1 Actualizar `SignUpView.swift` con la restricción de contraseña (10..25 caracteres y al menos 1 letra mayúscula) y feedback visual en tiempo real.
- [x] 2.2 Crear `AuthGateView.swift` como interfaz mandatoria de autenticación (Login/Registro sin botón de cancelar).
- [x] 2.3 Modificar `RootView.swift` para que alterne de forma excluyente entre `AuthGateView` (si `.unauthenticated`) y la interfaz principal (si `.authenticated`).

## 3. Swift Client Core Data Session Isolation & Full Synchronization

- [x] 3.1 Añadir método `clearAllUserData()` a `LibraryStore.swift` para purgar todas las entidades locales al cerrar sesión o antes de sincronizar una nueva cuenta.
- [x] 3.2 Actualizar `BackendAPIClient.swift` para soportar envío de `youtube_video_id` en peticiones de favoritos, historial y canciones de playlists.
- [x] 3.3 Implementar `syncAllUserDataWithBackend()` en `AppEnvironment.swift` para descargar e instanciar en Core Data la colección completa del usuario al iniciar sesión (playlists con canciones, favoritos e historial).
- [x] 3.4 Conectar acciones de usuario (`toggleFavorite`, `addTrackToPlaylist`, `removeTrackFromPlaylist`, `recordPlayHistory`) para sincronizar en tiempo real contra los endpoints del backend.
- [x] 3.5 Actualizar la acción de `logout()` en `AppEnvironment.swift` para purgar Core Data completamente.

## 4. Verification & Validation

- [x] 4.1 Ejecutar `./scripts/verify-no-secrets.py` para asegurar que ningún secreto sea expuesto.
- [x] 4.2 Ejecutar las pruebas automáticas del cliente Swift con `xcodebuild` (macOS y iOS Simulator).
- [x] 4.3 Validar la especificación completa ejecutando `openspec validate enforce-mandatory-auth-and-sync --type change --strict`.
