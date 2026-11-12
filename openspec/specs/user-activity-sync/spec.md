# user-activity-sync Specification

## Purpose
Ensure complete bidirectional synchronization of user library activity—including favorites, playlists, play history, and player state—between Swift local Core Data cache and FastAPI backend SQL database with isolated user session memory.

## Requirements

### Requirement: Full User Activity Synchronization
The system SHALL synchronize user library activity—including favorite tracks, playlists with ordered tracks, listening history, and player state—bidirectionally between each client's local cache and the backend API, using the backend as the source of truth and the backend playlist identifier as the shared key.

#### Scenario: Full library download on authentication
- **WHEN** a user logs in successfully or restores a valid session
- **THEN** the system purges any existing local cache and fetches remote playlists with their ordered tracks, favorites, and recent play history from the backend, populating the local view state.

#### Scenario: Real-time favorite synchronization
- **WHEN** a user toggles a track as favorite in any client
- **THEN** the system updates the local UI immediately and issues a real-time request to the backend API to reflect the favorite status in the database.

#### Scenario: Playlist track and order synchronization
- **WHEN** a user creates a playlist, adds a track, removes a track, renames, or deletes a playlist
- **THEN** the system persists the change to local storage and updates the same backend playlist, identified by its backend id, via the corresponding API endpoint.

#### Scenario: Restore after reinstall keeps every track
- **GIVEN** a playlist with three tracks stored in the backend for the account
- **WHEN** the user installs the app again and logs in
- **THEN** the local playlist shows the same name and the same three tracks in the same order.

#### Scenario: History restored newest first
- **GIVEN** the backend history contains track A played after track B
- **WHEN** the client restores the history
- **THEN** track A appears before track B in the local history.

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

### Requirement: Unique playlist names per account
The backend SHALL keep at most one playlist per account for a given name, compared case-insensitively.

#### Scenario: Creating an existing name returns the existing playlist
- **GIVEN** the account owns a playlist named "Gym"
- **WHEN** the client creates a playlist named "gym"
- **THEN** the response returns the existing playlist id and no new playlist is stored.

#### Scenario: Concurrent creates with the same name
- **WHEN** two create requests for the same name arrive at the same time
- **THEN** only one playlist with that name exists for the account and both responses carry its id.

#### Scenario: Renaming to a taken name is rejected
- **GIVEN** the account owns playlists "Gym" and "Chill"
- **WHEN** the client renames "Chill" to "GYM"
- **THEN** the backend responds 409 and both playlists keep their names.

#### Scenario: Different accounts may reuse a name
- **WHEN** two different accounts each create a playlist named "Gym"
- **THEN** each account owns its own playlist.

### Requirement: Playlist tracks append in order without duplicates
The backend SHALL append an added track at the end of the playlist and SHALL ignore a track already present.

#### Scenario: Tracks keep insertion order
- **WHEN** the client adds tracks A, B and C to a playlist in that order
- **THEN** the playlist returns A, B, C in that order.

#### Scenario: Adding a track twice keeps one copy
- **WHEN** the client adds track A to a playlist that already contains it
- **THEN** the playlist still contains A once and keeps its position.

### Requirement: Existing duplicate playlists are merged
The backend SHALL merge, at startup, every group of same-name playlists of an account into the oldest one, keeping the union of their tracks.

#### Scenario: Duplicates from older clients collapse into one
- **GIVEN** an account owns three playlists named "Gym" with tracks [A], [] and [B, A]
- **WHEN** the backend starts
- **THEN** the account owns one playlist "Gym", it is the oldest one, and it contains A and B once each.

### Requirement: Rapid edits never create extra playlists
A client SHALL never create more than one backend playlist per local playlist, regardless of how quickly tracks are added.

#### Scenario: Importing many tracks at once
- **WHEN** the user creates a playlist and immediately adds ten tracks to it
- **THEN** the backend holds exactly one playlist with that name containing the ten tracks.

#### Scenario: Rename then add
- **GIVEN** a synced playlist "Chill"
- **WHEN** the user renames it to "Noche" and then adds a track
- **THEN** the backend holds one playlist "Noche" with the track and no playlist "Chill".
