# mandatory-auth-gate Specification

## Purpose
Enforce mandatory authentication gate upon application launch, requiring users to log in or register before accessing any media player, library, or playback functions. Enforce password complexity (10-25 characters and at least one uppercase letter).

## Requirements

### Requirement: Mandatory Authentication Root Gate
The system SHALL require an authenticated user session before granting access to any application features, player controls, media browsing, or local library views. When unauthenticated, the application root SHALL exclusively display the authentication gate screen without options to bypass, dismiss, or use guest mode.

#### Scenario: App launch without session
- **WHEN** the application is launched and no valid authentication token is stored
- **THEN** the system displays the mandatory authentication gate screen requiring login or registration.

#### Scenario: Session logout
- **WHEN** the user initiates a logout or the session token is invalidated
- **THEN** the system revokes access to the main player and navigation interfaces and returns immediately to the authentication gate screen.

### Requirement: Password Complexity Validation
The system SHALL enforce password length between 10 and 25 characters inclusive and require at least one uppercase letter for all account creation requests. Validation MUST be enforced both client-side prior to submission and server-side in the registration endpoint.

#### Scenario: Registration with valid password
- **WHEN** a user enters a password containing between 10 and 25 characters with at least one uppercase letter
- **THEN** client-side validation passes and the registration request is submitted successfully to the backend.

#### Scenario: Registration with short or missing uppercase password
- **WHEN** a user enters a password shorter than 10 characters, longer than 25 characters, or lacking an uppercase letter
- **THEN** the system prevents form submission, displays a clear error message, and the backend rejects invalid registration payloads with a validation HTTP error status.
