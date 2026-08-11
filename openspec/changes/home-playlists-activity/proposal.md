# Proposal: Home Screen Apple Music Overhaul, Multi-Device Auth Sync, Playlist Management & Activity Logging

## Motivation
To provide a complete Apple Music "Listen Now / Escuchar" experience in **diego-music**, the application needs an upgraded Home screen featuring dynamic personalized greetings, hero carousel banners with glassmorphism dark aesthetic, horizontal recent history, and "Hecho para ti" recommendation mixes. Furthermore, all user data (playlists, history, favorites, player queue state) must be stored in the central FastAPI database and synced across multiple devices. Complete non-blocking user activity logging (login, playback, skips, searches, playlist edits) is required for analytics and recommendations.

## Proposed Changes
1. **Apple Music Home Screen (Escuchar / Listen Now):**
   - Personal Header: Dynamic time-based greeting (*"Buenos días"*, *"Buenas tardes"*, *"Buenas noches"*) with logged-in user name and avatar.
   - Hero Carousel: High-impact dark gradient banners (`#000000`/`#161618`) with glassmorphism translucent overlays, smooth press/hover lift scaling.
   - Escuchado Recientemente: Horizontal scroll row featuring square artwork from recent play history.
   - Hecho Para Ti: Recommendation cards and personalized mixes based on listening habits.

2. **Database Models & API Enhancements:**
   - Extend `app/models.py` and `app/schemas.py` for playlist updates and track reordering.
   - Extend `app/routers/playlists.py` with `PUT /playlists/{id}` (edit playlist details) and `PUT /playlists/{id}/tracks/reorder` (reorder playlist tracks).
   - Ensure `UserActivityLog` and `PlayHistory` link cleanly to users and tracks.

3. **Multi-Device Auth & Sync:**
   - Multi-device support via JWT authentication on FastAPI.
   - User player state synchronization (`/users/me/player-state`), play history (`/users/me/history`), and favorites (`/users/me/favorites`).

4. **Async Activity Telemetry:**
   - Asynchronous non-blocking event telemetry (`POST /telemetry/events`) for logins, play, pause, skip, searches, favorites, and playlist operations.

5. **Swift Frontend Integration:**
   - Update `HomeView.swift` and `HomeViewModel.swift` to render dynamic greeting with user name, horizontal recent history, and "Hecho para ti" mixes.
   - Update `PlaylistsView.swift` and `LibraryStore` / backend playlist client to support full CRUD (create, edit, reorder, delete).
