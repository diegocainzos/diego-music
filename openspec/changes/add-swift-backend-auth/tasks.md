# Implementation Tasks: Swift Auth Integration

- [ ] **1. Modelos de Autenticación & Token Storage**
  - [ ] Crear `DiegoMusic/Core/Networking/AuthModels.swift` (`AuthTokenResponse`, `UserDTO`, `LoginRequest`).
  - [ ] Crear `DiegoMusic/Core/Networking/KeychainTokenManager.swift` para gestionar tokens de acceso de forma segura.

- [ ] **2. Cliente HTTP `AuthClient`**
  - [ ] Crear `DiegoMusic/Core/Networking/AuthClient.swift` con métodos `login`, `register`, `fetchMe` y `updateMe`.
  - [ ] Escribir tests unitarios en `Tests/AuthClientTests.swift`.

- [ ] **3. Estado de Sesión en `AppEnvironment`**
  - [ ] Añadir `AuthState` (`.unauthenticated`, `.authenticated(User)`, `.loading`) en `DiegoMusic/App/AppEnvironment.swift`.
  - [ ] Comprobar token al arranque y cargar perfil.

- [ ] **4. Vistas SwiftUI (Login, Sign Up & Profile)**
  - [ ] Crear `DiegoMusic/Features/Auth/LoginView.swift` con estética Bauhaus Hi-Fi.
  - [ ] Crear `DiegoMusic/Features/Auth/SignUpView.swift`.
  - [ ] Integrar vista de Perfil y botón "Cerrar Sesión" en `DiegoMusic/Features/Settings/SettingsView.swift`.

- [ ] **5. Regeneración de Proyecto & Validación**
  - [ ] Regenerar proyecto con `./scripts/generate-project.sh`.
  - [ ] Ejecutar build-for-testing y `xcodebuild` tests.
