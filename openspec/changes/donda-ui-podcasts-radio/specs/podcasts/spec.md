# Especificación: podcasts

## ADDED Requirements

### Requirement: Seguir programas
The user SHALL be able to follow and unfollow YouTube channels as podcast shows from Buscar and from the show detail; followed shows MUST persist in Core Data (`FollowedShow`). The Joe Rogan Experience and The Wild Project SHALL be seeded once by fixed channel ID (no search request), and an explicit unfollow MUST stick. Followed shows and episode progress are device-local: the backend sync wipe MUST NOT delete them; only logout does.

#### Scenario: Seguir desde Buscar
- **WHEN** the user searches a channel and taps «Seguir»
- **THEN** the button changes to «Siguiendo» and the show appears in Biblioteca › Podcasts and in Inicio › «Tus podcasts»

#### Scenario: Siembra inicial
- **WHEN** the app launches for the first time after this change
- **THEN** JRE and The Wild Project are followed

### Requirement: Solo episodios completos
The show detail SHALL list the channel's uploads with duration of at least 40 minutes, newest first, obtained via the channel uploads playlist and `videos.list` durations; it MUST NOT use `search.list` for episode listing.

#### Scenario: Canal con clips
- **WHEN** a channel's latest uploads include 10-minute clips and 3-hour episodes
- **THEN** only the 3-hour episodes appear, and a note states how many short videos were hidden

### Requirement: Reanudar episodios
The player SHALL persist per-episode progress (`EpisodeProgress`) on pause, every 15 seconds while playing and on track change, mark it finished when 60 seconds or less remain, and resume from the saved position when the episode is played again.

#### Scenario: Retomar
- **WHEN** the user plays an episode previously paused at 1:12:30
- **THEN** playback starts at 1:12:30 and a toast says «Reanudando en 1:12:30»

#### Scenario: Episodio terminado
- **WHEN** an episode is marked finished and the user plays it
- **THEN** playback starts from the beginning

### Requirement: Velocidad y saltos de episodio
For episodes the player SHALL offer speeds 1×, 1.25×, 1.5×, 1.75× and 2×, skip back 15 s and skip forward 30 s, including in `MPRemoteCommandCenter`; music MUST always play at 1× and keep next/previous remote commands.

#### Scenario: Cambiar velocidad
- **WHEN** the user taps the speed button on an episode at 1×
- **THEN** playback rate becomes 1.25× and is remembered for the next episode

#### Scenario: Volver a música
- **WHEN** a music track starts after an episode played at 2×
- **THEN** the track plays at 1× and lock-screen controls show previous/next

### Requirement: Descarga de episodios
Each episode row and the episode player SHALL offer download through the existing offline download manager, showing progress and a downloaded state, and downloaded episodes SHALL appear in Biblioteca › Descargas.

#### Scenario: Descargar
- **WHEN** the user taps download on an episode
- **THEN** the row shows a percentage until complete and then a check, and the episode plays offline
