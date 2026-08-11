# Auth Client & SwiftUI Login/SignUp Delta Specification

## ADDED Requirements

### Requirement: Client Authentication & Token Storage
The Swift application MUST provide secure authentication against the FastAPI backend endpoints `/api/v1/auth/*` and store access tokens securely.

#### Scenario: Successful user login
- **WHEN** the user provides valid email and password credentials in `LoginView`
- **THEN** `AuthClient` sends an OAuth2 password request to `/api/v1/auth/login`
- **AND** stores the returned JWT `access_token` in `KeychainTokenManager`
- **AND** updates `AppState` to `.authenticated(user)`.

#### Scenario: User registration
- **WHEN** a new user submits the `SignUpView` form with full name, email, and password
- **THEN** `AuthClient` sends a POST request to `/api/v1/auth/register`
- **AND** automatically authenticates the user upon successful registration response.

### Requirement: SwiftUI Login and Sign Up Interfaces
The application MUST provide Bauhaus Hi-Fi styled SwiftUI views for login, sign up, and account profile management.

#### Scenario: Display login screen when unauthenticated
- **WHEN** the user launches the application without a valid saved token
- **THEN** the application presents `LoginView` with controls for credentials input and switching to `SignUpView`.

#### Scenario: User profile & Logout in Settings
- **WHEN** an authenticated user opens `SettingsView`
- **THEN** the user's name and avatar are displayed in the profile header section
- **AND** a "Cerrar Sesión" button clears the token and resets `AppState` to `.unauthenticated`.
