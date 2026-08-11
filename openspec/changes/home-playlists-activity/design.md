# Design: Home Screen, Multi-Device Sync, Internal Playlists & Async Activity Logging

## Architectural Overview

### 1. Home Screen UI/UX (Apple Music Aesthetic)
- **Header:** Reads `AppEnvironment.authState` to extract `User.full_name` or email, displaying dynamic greetings (*"Buenas noches, [Nombre]"*) and user avatar.
- **Hero Carousel:** Horizontal card scroll with dark gradient styling (`#000000`/`#161618`), `.ultraThinMaterial` glassmorphism accents, and hover-lift micro-interactions (`TilePressButtonStyle`).
- **Recently Played:** Horizontal scroll section powered by `PlayHistory` data.
- **Hecho Para Ti (Made For You):** Personalized mix cards (*"Mix de Descubrimiento"*, *"Mix de Favoritos"*, *"Mix Relax"*) based on top played genres and artists.

### 2. FastAPI Backend & Database
- **Playlist Management API:**
  - `POST /api/v1/playlists/`: Create playlist.
  - `GET /api/v1/playlists/me`: Retrieve user playlists.
  - `GET /api/v1/playlists/{id}`: Detailed playlist with ordered tracks.
  - `PUT /api/v1/playlists/{id}`: Edit name, description, cover_url, is_public.
  - `POST /api/v1/playlists/{id}/tracks`: Add track with position.
  - `PUT /api/v1/playlists/{id}/tracks/reorder`: Reorder track list.
  - `DELETE /api/v1/playlists/{id}/tracks/{track_id}`: Remove track.
  - `DELETE /api/v1/playlists/{id}`: Delete playlist.
- **User Activity Telemetry API:**
  - `POST /api/v1/telemetry/events`: Non-blocking async event logging for player events, searches, auth, and playlist actions.

### 3. Swift Frontend & Networking Integration
- **`TelemetryLogger`:** Async non-blocking service executing background `Task.detached` requests to send event logs without interfering with main thread audio playback.
- **`HomeViewModel`:** Coordinates loading catalog recommendations, recent play history, and personalized mixes.
- **`PlaylistsView`:** Full CRUD UI with reordering support.
