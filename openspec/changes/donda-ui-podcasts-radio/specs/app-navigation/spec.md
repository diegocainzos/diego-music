# Especificación: navegación y reproductor

## ADDED Requirements

### Requirement: Tres pestañas
On iPhone the app SHALL show exactly three tabs: Inicio, Buscar and Biblioteca; on macOS and iPad the sidebar SHALL list the same three sections.

#### Scenario: Barra de pestañas en iPhone
- **WHEN** the app shows the main interface on iPhone
- **THEN** the tab bar contains Inicio, Buscar and Biblioteca and nothing else

### Requirement: Inicio sin bandeja de novedades
Inicio SHALL show, in order, «Continuar» (the most recently played unfinished episode, if any), «Escuchado hace poco» and «Tus podcasts», and MUST NOT show a «Nuevos episodios» section.

#### Scenario: Episodio a medias
- **WHEN** an episode of a followed show has saved progress and is not finished
- **THEN** Inicio shows it under «Continuar» with its progress bar and remaining time, and tapping play resumes it

### Requirement: Biblioteca segmentada
Biblioteca SHALL expose the segments Playlists, Podcasts, Canciones, Álbumes, Artistas and Descargas, and SHALL open Ajustes from a header button.

#### Scenario: Abrir podcasts seguidos
- **WHEN** the user selects the Podcasts segment
- **THEN** followed shows are listed and tapping one opens the podcast detail

### Requirement: Mini-player flotante
While something is loaded and the player is minimized, the mini-player SHALL float above the content and above the tab bar with side margins, a 1 pt `outline` border and a shadow, showing title, subtitle, play/pause and next (music) or +30 s (episode), plus a 1 pt progress line.

#### Scenario: Desplazar contenido bajo el mini-player
- **WHEN** the user scrolls a long list to the end
- **THEN** the last row is fully visible above the mini-player

#### Scenario: Expandir
- **WHEN** the user taps the mini-player outside its buttons
- **THEN** the expanded player opens

### Requirement: Reproductor expandido Donda
The expanded player SHALL show a header (close chevron, centered source title), a full-width square artwork with a `hairline` border that subtly pulses while playing, title and subtitle, a linear progress slider with elapsed and remaining time, and mode-specific controls; the circular halo scrubber MUST be removed.

#### Scenario: Controles de música
- **WHEN** the current item is a music track
- **THEN** the controls are shuffle, previous, play/pause, next and repeat, followed by the radio button and the upcoming queue

#### Scenario: Controles de episodio
- **WHEN** the current item is a podcast episode
- **THEN** the controls are speed, −15 s, play/pause, +30 s and download, and the header title opens the show detail
