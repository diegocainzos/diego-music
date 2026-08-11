# Tasks: Home Screen, Multi-Device Sync, Internal Playlists & Async Activity Logging

- [x] Create proposal, design, and delta spec under `openspec/changes/home-playlists-activity/` <!-- id: 0 -->
- [ ] Extend FastAPI Backend Playlist & Telemetry Endpoints (`PUT /playlists/{id}`, `PUT /playlists/{id}/tracks/reorder`, telemetry logging) <!-- id: 1 -->
- [ ] Add backend unit tests for playlist updates, reordering, and activity logging <!-- id: 2 -->
- [ ] Implement Swift background `TelemetryLogger` for non-blocking activity logging <!-- id: 3 -->
- [ ] Enhance SwiftUI `HomeView` with dynamic greeting, Apple Music glassmorphism hero carousel, horizontal recently played row, and "Hecho para ti" section <!-- id: 4 -->
- [ ] Update Swift `PlaylistsView` and API client for full playlist CRUD and track reordering <!-- id: 5 -->
- [ ] Run validation scripts (`validate-resolver.sh`, `pytest`) and check git status <!-- id: 6 -->
