## Why

Actualmente, el soporte mixto entre uso anónimo local y cuentas privadas en DiegoMusic genera un colapso en la experiencia de usuario y en la integridad de los datos. El estado de Core Data local permanecía desvinculado de la API del servidor, provocando que las listas de reproducción, los favoritos y el historial de escuchas no se sincronizaran o se contaminaran entre sesiones. Además, los requisitos de contraseña eran inseguros (mínimo 6 caracteres sin reglas de complejidad).

Hacer que la aplicación sea 100% dependiente de inicio de sesión y sincronizar toda la actividad del usuario contra el backend resolverá la desincronización, garantizará el aislamiento total entre cuentas y proporcionará una experiencia fluida y segura.

## What Changes

- **BREAKING**: Eliminación total del modo local/invitado sin autenticación. Al abrir la app, la pantalla raíz exige inicio de sesión o registro (`AuthGateView`).
- **NUEVA SEGURIDAD**: Restricción estricta de contraseñas: longitud obligatoria entre 10 y 25 caracteres, con al menos una letra mayúscula. Validado de forma redundante en Swift (`SignUpView`) y en FastAPI (`UserCreate` Pydantic schema).
- **SINCRONIZACIÓN TOTAL DE ACTIVIDAD**:
  - Limpieza completa del almacenamiento local (Core Data) al cerrar sesión o iniciar sesión con otra cuenta para aislar sesiones.
  - Sincronización bidireccional automática al autenticarse: descarga de playlists (con sus pistas y orden), favoritos e historial reciente desde el backend.
  - Actualización síncrona en tiempo real: agregar/quitar favoritos, modificar listas o reproducir canciones invoca inmediatamente las rutas del backend (`/users/me/favorites`, `/playlists/*`, `/users/me/history`).
- **PUENTE DE IDENTIFICADORES DE CANCIONES**: Modificación de las peticiones/respuestas del backend para resolver e ingresar pistas mediante `youtube_video_id` (string), eliminando el fallo de conversión a `Int` en el cliente Swift.

## Capabilities

### New Capabilities
- `mandatory-auth-gate`: Flujo de entrada obligatorio de autenticación y validación estricta de contraseñas (10-25 caracteres + 1 mayúscula).
- `user-activity-sync`: Sincronización completa y aislamiento de sesión de la biblioteca, playlists, favoritos, historial y estado del reproductor.

### Modified Capabilities
(Ninguna capacidad existente en `openspec/specs/`)

## Impact

- **Swift Client**: `RootView.swift`, `AppEnvironment.swift`, `LoginView.swift`, `SignUpView.swift`, `LibraryStore.swift`, `BackendAPIClient.swift`, `NavigationState.swift`.
- **FastAPI Backend**: `app/schemas.py`, `app/routers/auth.py`, `app/routers/users.py`, `app/routers/playlists.py`, `app/models.py`.
- **Tests**: Actualización de suites `test_backend_auth.py` y tests de Swift para cumplir la regla de contraseñas `10..25` con mayúscula.
