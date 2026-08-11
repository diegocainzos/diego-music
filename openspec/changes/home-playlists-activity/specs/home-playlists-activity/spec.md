# Home Screen, Multi-Device Sync, Internal Playlists & Activity Logging Specification

## ADDED Requirements

### Requirement: Apple Music Styled Home Screen ("Escuchar")
The application MUST provide a modern Apple Music inspired Home screen with personalized greeting, hero carousel banners, horizontal recent play history, and personalized recommendation mixes.

#### Scenario: Display personalized header greeting
- **WHEN** an authenticated user opens the Home tab
- **THEN** the header displays a time-of-day greeting including the user's name (e.g., *"Buenas noches, Diego"*) and user avatar.

#### Scenario: Display hero carousel with dark glassmorphism aesthetic
- **WHEN** viewing the top section of the Home screen
- **THEN** high-impact dark gradient banners with rounded corners and glassmorphism styling are displayed with smooth press animation.

#### Scenario: Horizontal recently played history
- **WHEN** the user has listening history
- **THEN** a horizontal scrolling row displays square cover art of recently played tracks.

#### Scenario: Hecho Para Ti recommendation mixes
- **WHEN** viewing the recommendation section
- **THEN** personalized mix cards ("Mix de Descubrimiento", "Mix de Favoritos") are available for quick playback.

### Requirement: Internal Playlist CRUD & Reordering API
The FastAPI backend MUST provide full CRUD endpoints and track reordering for user playlists.

#### Scenario: Update playlist metadata
- **WHEN** an authenticated user sends a PUT request to `/api/v1/playlists/{playlist_id}` with updated name or description
- **THEN** the playlist details are updated in the database and returned.

#### Scenario: Reorder tracks in playlist
- **WHEN** an authenticated user sends a PUT request to `/api/v1/playlists/{playlist_id}/tracks/reorder` with an ordered track ID list
- **THEN** the `order` column for each `PlaylistTrack` is updated accordingly.

### Requirement: Non-Blocking User Activity Telemetry
The application MUST record user activity events (login/logout, play, pause, skip, search, favorites, playlist edits) in background tasks without blocking UI or audio playback.

#### Scenario: Record playback and user interaction events
- **WHEN** a user triggers a play, pause, skip, search, or playlist edit event
- **THEN** the client sends an async non-blocking telemetry log to `/api/v1/telemetry/events`.
