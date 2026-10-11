# Especificación: cliente Android

## ADDED Requirements

### Requirement: Paridad funcional con el cliente Swift
The Android app SHALL implement the same user-facing features as the Swift client on `main`: mandatory authentication, search, artist and album detail, playback queue, explicit radio, «PARA TI» recommendations, favorites, playlists (create, rename, delete, reorder, import from YouTube, download), history, podcasts, offline downloads, synced lyrics and settings, using the same backend and resolver endpoints without modifying them.

#### Scenario: Iniciar sesión
- **WHEN** the user opens the app without a stored token
- **THEN** only the login/register gate is shown and it cannot be dismissed
- **AND** after a successful login favorites, playlists and history are synced from `/api/v1`

#### Scenario: Sesión caducada
- **WHEN** the stored token is rejected by `/api/v1/auth/me`
- **THEN** the token and local user data are deleted and the gate is shown

### Requirement: Un único reproductor con sesiones opacas
The app SHALL play audio through a single Media3 player owned by `PlayerCoordinator`, sending only a validated `videoId` to `POST /v1/audio/resolve` with the user's JWT, playing the returned opaque `streamURL`, never handling upstream URLs, retrying at most once on a player error after invalidating the cached session, and prefetching the next track silently without changing the current one.

#### Scenario: ID inválido
- **WHEN** a track whose ID does not match `^[A-Za-z0-9_-]{11}$` is played
- **THEN** no resolver request is made and a sanitized error is shown

#### Scenario: Sesión expirada durante la reproducción
- **WHEN** the player fails to open a resolved stream
- **THEN** the session is invalidated and resolved again once
- **AND** a second failure shows a sanitized error instead of retrying

#### Scenario: Pista descargada
- **WHEN** the current track is downloaded
- **THEN** it plays from the local file without contacting the resolver

### Requirement: Reproducción en segundo plano y controles del sistema
The app SHALL keep playing with the screen off or the app in background, and SHALL publish title, artist, artwork, position and controls to the media notification and lock screen; music SHALL expose previous/next, episodes SHALL expose −15 s/+30 s, and music MUST always play at 1×.

#### Scenario: Pantalla bloqueada con música
- **WHEN** a music track plays and the screen is locked
- **THEN** the lock screen shows previous, play/pause and next, and next advances the queue

#### Scenario: Pantalla bloqueada con un episodio
- **WHEN** an episode plays at 1.5× and the screen is locked
- **THEN** the controls are −15 s, play/pause and +30 s and playback continues at 1.5×

### Requirement: Catálogo idéntico al de Swift
The app SHALL query YouTube Data API v3 with the same endpoints and parameters as the Swift client, rotate keys on quota errors (403 quota or 429), fall back to the resolver's `/v1/search` and `/v1/artist/{id}` when every key is exhausted, cache first-page searches for 24 h with case-, accent- and whitespace-insensitive keys, and never log or display API URLs or keys.

#### Scenario: Cuota agotada
- **WHEN** every configured key returns a quota error for a search
- **THEN** the results come from `/v1/search` and are cached like any other search

#### Scenario: Búsqueda repetida
- **WHEN** the user searches «Coldplay  Yellow» after «coldplay yellow»
- **THEN** no new network request is made

### Requirement: Seguir canales desde Buscar
Search SHALL also return matching YouTube channels, listed before videos with a «SEGUIR»/«SIGUIENDO» toggle, and the «Artistas» scope SHALL show those channels.

#### Scenario: Seguir un podcast
- **WHEN** the user searches «the wild project» and taps «SEGUIR» on the channel row
- **THEN** the button reads «SIGUIENDO» and the show appears in Biblioteca › Podcasts and Inicio › «TUS PODCASTS»

### Requirement: Podcasts con progreso y velocidad
The app SHALL list only uploads of at least 40 minutes for a followed show (via the uploads playlist and `videos.list`, never `search.list`), persist per-episode progress on pause, every 15 s and on track change, mark an episode finished with 60 s or less remaining, resume from the saved position, and offer speeds 1×, 1.25×, 1.5×, 1.75× and 2× remembered across episodes.

#### Scenario: Retomar
- **WHEN** the user plays an episode previously paused at 1:12:30
- **THEN** playback starts at 1:12:30 and a toast reads «REANUDANDO EN 1:12:30»

#### Scenario: Siembra inicial
- **WHEN** the app runs for the first time
- **THEN** The Joe Rogan Experience and The Wild Project are followed, and an explicit unfollow is kept on later launches

### Requirement: Descargas offline atómicas
Downloads SHALL be processed one at a time with up to two retries, written to a temporary file and renamed only when complete, show per-track progress, appear in Biblioteca › Descargas, and MUST NOT leave partial files playable.

#### Scenario: Descarga interrumpida
- **WHEN** the network drops halfway through a download
- **THEN** the temporary file is removed and the track shows the failed state with a sanitized message

### Requirement: Letras sincronizadas
The lyrics screen SHALL use the same LRCLIB metadata cleaning, five-stage query cascade and candidate scoring as the Swift client, highlight and auto-scroll the active line, pause auto-scroll for 3 s after a manual drag, seek on tap, and keep the line column fixed to the viewport width.

#### Scenario: Título de YouTube ruidoso
- **WHEN** the track is «Lady Gaga - Abracadabra (Official Music Video)» from channel «LadyGagaVEVO»
- **THEN** LRCLIB is queried with artist «Lady Gaga» and track «Abracadabra»

### Requirement: Lenguaje visual Donda
The Android UI SHALL use only the Donda tokens and themes of the Swift client (black by default, white, legacy values migrated), monospaced uppercase labels with tracking, condensed regular titles, radius 0, 1 dp borders, inverted active states and real color artwork in hairline-bordered squares.

#### Scenario: Cambiar a blanco
- **WHEN** the user selects «BLANCO» in Ajustes
- **THEN** every screen, the system bars, the mini-player and the expanded player switch to white without restarting

### Requirement: Estructura de pantallas Donda
The Android UI SHALL keep the Swift screen structure: three tabs (Inicio, Buscar, Biblioteca), a floating mini-player above the tab bar carrying the only allowed shadow, the segmented Library opening Ajustes in a sheet, and the expanded player with music and episode controls.

#### Scenario: Último elemento visible
- **WHEN** the user scrolls a long list to the end while something is loaded
- **THEN** the last row is fully visible above the mini-player

### Requirement: Credenciales fuera del repositorio
The build SHALL read `YOUTUBE_DATA_KEY` and `AUDIO_RESOLVER_BASE_URL` from the root `.env` or environment variables at build time, MUST NOT print them, MUST NOT write them to versioned files and MUST NOT embed the resolver's static token; resolver calls SHALL use the user's JWT, YouTube requests SHALL send `X-Android-Package` and `X-Android-Cert`, and the app SHALL show a configuration message instead of crashing when the base URL is missing.

#### Scenario: Sin .env
- **WHEN** the app is built without credentials
- **THEN** it builds, and playback shows «Configura el resolutor privado…» instead of failing silently
