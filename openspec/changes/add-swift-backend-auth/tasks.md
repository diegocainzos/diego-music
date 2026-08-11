# Implementation Tasks: Swift Auth Integration

- [x] **1. Modelos de Autenticación & Token Storage**
  - [x] Crear `DiegoMusic/Core/Networking/AuthModels.swift` (`AuthTokenResponse`, `UserDTO`, `LoginRequest`).
  - [x] Crear `DiegoMusic/Core/Networking/KeychainTokenManager.swift` para gestionar tokens de acceso de forma segura.

- [x] **2. Cliente HTTP `AuthClient`**
  - [x] Crear `DiegoMusic/Core/Networking/AuthClient.swift` con métodos `login`, `register`, `fetchMe` y `updateMe`.
  - [x] Escribir tests unitarios en `Tests/AuthClientTests.swift`.

- [x] **3. Estado de Sesión en `AppEnvironment`**
  - [x] Añadir `AuthState` (`.unauthenticated`, `.authenticated(User)`, `.loading`) en `DiegoMusic/App/AppEnvironment.swift`.
  - [x] Comprobar token al arranque y cargar perfil.

- [x] **4. Vistas SwiftUI (Login, Sign Up & Profile)**
  - [x] Crear `DiegoMusic/Features/Auth/LoginView.swift` con estética Bauhaus Hi-Fi.
  - [x] Crear `DiegoMusic/Features/Auth/SignUpView.swift`.
  - [x] Integrar vista de Perfil y botón "Cerrar Sesión" en `DiegoMusic/Features/Settings/SettingsView.swift`.

- [x] **5. Regeneración de Proyecto & Validación**
  - [x] Regenerar proyecto con `./scripts/generate-project.sh`.
  - [x] Ejecutar build-for-testing y `xcodebuild` tests.
