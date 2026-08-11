# Proposal: Integración de Autenticación en el Cliente Swift (iOS / macOS)

## Motivation
El backend FastAPI ya cuenta con endpoints operativos de autenticación (`/api/v1/auth/register`, `/api/v1/auth/login`, `/api/v1/auth/me`) y sincronización de preferencias/historial. Actualmente, el cliente Swift funciona en modo anónimo con almacenamiento puramente local. Se requiere integrar autenticación nativa (Login, Registro, Gestión de Sesión y Tokens JWT) en el cliente iOS/macOS para vincular la experiencia del usuario con la cuenta centralizada.

## Proposed Changes
1. **Modelos y Gestión de Tokens:**
   - Crear `AuthTokenManager` utilizando `Keychain` / `UserDefaults` seguro para almacenar el JWT access token.
   - Definir modelos `User`, `AuthTokenResponse`, `LoginPayload` y `RegisterPayload`.
2. **Cliente de Red `AuthClient`:**
   - Implementar el cliente HTTP con concurrencia Swift (`async/await`) para llamar a los endpoints `/api/v1/auth/*`.
   - Inyectar el header `Authorization: Bearer <token>` automáticamente en las peticiones autenticadas.
3. **Estado de Sesión Global (`AuthState` / `AppEnvironment`):**
   - Publicar el estado de autenticación (`.authenticated(User)`, `.unauthenticated`, `.loading`).
   - Sincronizar el perfil del usuario activo en toda la app.
4. **Interfaz de Usuario (SwiftUI):**
   - Diseñar `LoginView` y `SignUpView` respetando el sistema de diseño Bauhaus Hi-Fi de DiegoMusic.
   - Integrar formulario de email, contraseña, nombre completo e imagen de avatar.
   - Añadir pantalla de perfil / cerrar sesión dentro de `SettingsView`.

## Verification Plan
- Pruebas unitarias en Swift (`Tests/AuthClientTests.swift`) simulando respuestas de backend (`URLProtocol` mock).
- Verificación en simulador iOS y app ejecutable de macOS.
- Compilación limpia con Xcode mediante `xcodebuild`.
