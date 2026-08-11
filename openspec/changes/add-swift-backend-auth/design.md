# Design: Integración de Autenticación Swift en DiegoMusic

## Architecture & Data Flow

```text
[ LoginView / SignUpView ] 
       │
       ▼
 [ AuthViewModel / AuthState ] ──(KeychainStore)──► [ JWT Access Token ]
       │
       ▼
  [ AuthClient ] ────────────(HTTPS Bearer)──────────► [ FastAPI /api/v1/auth/* ]
```

### 1. `AuthTokenManager`
- Responsable de persistir y recuperar de forma segura el JWT token del usuario.
- Proporciona utilidades para comprobar expiración previa del token antes de realizar solicitudes HTTP.

### 2. `AuthClient` Actor / Service
- Protocolo `AuthClientProtocol` inyectable para facilitar pruebas con Mocks.
- Métodos:
  - `login(email:password:) async throws -> AuthTokenResponse`
  - `register(email:password:fullName:) async throws -> AuthTokenResponse`
  - `fetchProfile() async throws -> User`
  - `updateProfile(fullName:avatarURL:) async throws -> User`
  - `logout()`

### 3. Integración en `AppEnvironment`
- `AppEnvironment` mantendrá una instancia publicada `@Published var authState: AuthState`.
- Al iniciar la app, comprueba la existencia de un token guardado. Si existe, valida `/api/v1/auth/me`. Si es válido, inicia sesión automáticamente (`.authenticated(user)`). Si no, pasa a `.unauthenticated`.

### 4. Vistas SwiftUI (Bauhaus Hi-Fi)
- `LoginView`: Campos de texto para Correo Electrónico y Contraseña con animación sutil de error y botón interactivo "Iniciar Sesión". Opción para cambiar a Registro.
- `SignUpView`: Campos para Nombre Completo, Correo Electrónico, Contraseña y Confirmación de Contraseña. Botón "Crear Cuenta".
- `ProfileHeaderView`: Tarjeta visual Bauhaus dentro de `SettingsView` mostrando Avatar, Nombre, Email y Botón de "Cerrar Sesión".

## Security & Concurrency Considerations
- Respetar `@MainActor` en `AuthViewModel` y mutaciones de UI.
- No guardar la contraseña en texto plano en disco bajo ninguna circunstancia.
- Manejo sanitizado de errores de autenticación ("Credenciales incorrectas", "El correo ya está registrado") sin exponer trazas técnicas internas.
