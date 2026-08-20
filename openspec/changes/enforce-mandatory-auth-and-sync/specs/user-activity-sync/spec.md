## ADDED Requirements

### Requirement: Full User Activity Synchronization
The system SHALL synchronize user library activity—including favorite tracks, playlists with ordered tracks, listening history, and player state—bidirectionally between the Swift local persistent cache and the FastAPI backend API.

#### Scenario: Full library download on authentication
- **WHEN** a user logs in successfully or restores a valid session
- **THEN** the system purges any existing local Core Data cache and fetches remote playlists, tracks, favorites, and recent play history from the backend, populating the local view state.

#### Scenario: Real-time favorite synchronization
- **WHEN** a user toggles a track as favorite in the iOS/macOS interface
- **THEN** the system updates the local UI immediately and issues a real-time request to the backend API to reflect the favorite status in the database.

#### Scenario: Playlist track and order synchronization
- **WHEN** a user creates a playlist, adds a track, removes a track, or reorders tracks in a playlist
- **THEN** the system persists the change to local storage and updates the backend playlist resource via the corresponding API endpoint.

### Requirement: YouTube Video ID Backend Bridge
The backend API SHALL accept YouTube video ID string identifiers for play history recording, favorite management, and playlist track management, resolving or creating the corresponding backend track record automatically.

#### Scenario: Record play history with YouTube video ID
- **WHEN** the client submits a play history event containing a YouTube video ID string (e.g. "dQw4w9WgXcQ")
- **THEN** the backend resolves or creates the track record for that video ID and records the play history entry without failing numerical conversion.

### Requirement: Session Data Isolation on Logout
The system SHALL purge all cached user data (playlists, tracks, favorites, history, saved albums) from local Core Data upon session logout to prevent cross-user data leakage.

#### Scenario: Data wipe on logout
- **WHEN** a user logs out of their account
- **THEN** all user-owned records in local storage are purged before any new authentication attempt.
