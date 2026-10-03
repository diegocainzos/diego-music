## MODIFIED Requirements

### Requirement: Full User Activity Synchronization
The system SHALL synchronize user library activity—including favorite tracks, playlists with their tracks, and listening history—bidirectionally between the Swift local persistent cache and the FastAPI backend API. Player state and playlist track order SHALL remain local to the device and MUST NOT be sent to the backend.

#### Scenario: Full library download on authentication
- **WHEN** a user logs in successfully or restores a valid session
- **THEN** the system purges any existing local Core Data cache and fetches remote playlists, tracks, favorites, and recent play history from the backend, populating the local view state.

#### Scenario: Real-time favorite synchronization
- **WHEN** a user toggles a track as favorite in the iOS/macOS interface
- **THEN** the system updates the local UI immediately and issues a real-time request to the backend API to reflect the favorite status in the database.

#### Scenario: Playlist membership synchronization
- **WHEN** a user creates a playlist, deletes a playlist, adds a track, or removes a track
- **THEN** the system persists the change to local storage and updates the backend playlist resource via the corresponding API endpoint.

#### Scenario: Local-only reordering
- **WHEN** a user reorders tracks in a playlist
- **THEN** the system persists the new order locally and issues no backend request.
