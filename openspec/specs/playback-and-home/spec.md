# playback-and-home Specification

## Purpose
TBD - created by archiving change ytm-layout-autoradio. Update Purpose after archive.

## Requirements

### Requirement: Radio automática al reproducir una pista suelta
The system SHALL, when the user plays a single track that is not part of an album, playlist or podcast episode, replace everything after that track in the queue with the YouTube Mix of that track without interrupting playback, and SHALL mark the radio as active.

#### Scenario: Pista suelta arranca el Mix
- **GIVEN** a queue with tracks A and B and A playing
- **WHEN** the user plays a single track C from search
- **THEN** C plays and the tracks after C are the Mix items for C, and the radio is shown as active

#### Scenario: Reproducir una lista no arranca la radio
- **WHEN** the user plays an album or playlist starting at its first track
- **THEN** the queue is exactly that list and the radio is not active

#### Scenario: Mix no disponible
- **GIVEN** the Mix service fails or returns no items
- **WHEN** the user plays a single track C
- **THEN** C keeps playing, the queue after C is left unchanged and the radio is not active

#### Scenario: Respuesta del Mix obsoleta
- **GIVEN** the Mix request for track C is still pending
- **WHEN** the user plays another single track D before it finishes
- **THEN** the Mix for C is never applied and the items after D are the Mix of D

#### Scenario: Parar la radio
- **GIVEN** the radio is active
- **WHEN** the user stops the radio
- **THEN** the Mix items after the current track are removed and the radio is not active

### Requirement: La vista de cola muestra lo que suena y lo que viene
The system SHALL show in the queue view the current track followed by up to 20 upcoming tracks in queue order, never tracks that come before the current one, and SHALL refresh it whenever the queue changes.

#### Scenario: Historial largo
- **GIVEN** a queue of 30 tracks with the 25th playing
- **WHEN** the queue view is shown
- **THEN** it lists tracks 25 to 30 with track 25 marked as current

#### Scenario: La radio cambia la vista
- **GIVEN** the queue view is shown with no upcoming tracks
- **WHEN** the Mix is loaded after the current track
- **THEN** the queue view lists the Mix tracks after the current track

#### Scenario: Seleccionar desde la vista
- **WHEN** the user taps the third row of the queue view
- **THEN** the track at that position after the current one starts playing

### Requirement: Selecciones rápidas en Inicio
The system SHALL show on Home a "Selecciones rápidas" section with up to 20 tracks picked at random from the user's saved songs, as a compact list where each row shows small square artwork, the title as the prominent text and the artist as secondary text, without a "Reproducir todo" action. The selection SHALL be reshuffled when Home appears, when the app returns to the foreground and when the saved songs change. No network request is made to build it.

#### Scenario: Con canciones guardadas
- **GIVEN** the library holds saved songs
- **WHEN** Home is shown
- **THEN** "Selecciones rápidas" lists at most 20 of them in random order without duplicates

#### Scenario: Se baraja al volver a la app
- **GIVEN** Home shows a list
- **WHEN** the app returns to the foreground
- **THEN** a new random selection of the saved songs is shown

#### Scenario: Reproducir una fila
- **WHEN** the user taps a row in "Selecciones rápidas"
- **THEN** that track plays as a single track

#### Scenario: Sin canciones guardadas
- **GIVEN** the library holds no saved songs
- **WHEN** Home is shown
- **THEN** the section is not shown

### Requirement: Sin recomendaciones por LLM
The system SHALL NOT show a "Para ti" section nor request LLM recommendations, and the resolver SHALL NOT expose a recommendations endpoint.

#### Scenario: Endpoint retirado
- **WHEN** an authenticated client sends `POST /v1/recommendations`
- **THEN** the resolver answers 404 or 405

#### Scenario: Inicio sin Para ti
- **GIVEN** the user has listening history
- **WHEN** Home is shown
- **THEN** no "Para ti" section appears

### Requirement: Pestañas del reproductor expandido
The system SHALL show, below the music transport controls of the expanded player, two tabs "A continuación" and "Letras"; the selected tab is shown inverted and only its content is visible. Podcast episodes SHALL keep their own controls without these tabs.

#### Scenario: Pestaña por defecto
- **WHEN** the expanded player opens for a music track
- **THEN** the "A continuación" tab is selected and the queue view is visible

#### Scenario: Cambiar a letras
- **WHEN** the user selects "Letras"
- **THEN** the lyrics of the current track replace the queue view inside the player

### Requirement: Títulos recortados en WebKit
The web client SHALL keep every track title and artist inside its row on WebKit-based browsers, truncating overflowing text with an ellipsis or a two-line clamp instead of overflowing.

#### Scenario: Título largo en Safari
- **GIVEN** a track whose title is longer than the row width
- **WHEN** a track row is rendered in a WebKit browser at 375 px width
- **THEN** the title's right edge does not exceed its row's right edge

### Requirement: Mix servido desde caché
The resolver SHALL cache the Mix of each video for a bounded time and number of entries, and concurrent requests for the same video SHALL share a single extraction. Failed or empty results SHALL NOT be cached.

#### Scenario: Segunda petición desde caché
- **GIVEN** the Mix of A was requested successfully
- **WHEN** the Mix of A is requested again before it expires
- **THEN** the same items are returned without a new extraction

#### Scenario: Peticiones simultáneas
- **WHEN** several requests for the Mix of A arrive at the same time
- **THEN** a single extraction runs and all of them get its items

#### Scenario: Caducidad
- **GIVEN** the cached Mix of A has expired
- **WHEN** the Mix of A is requested
- **THEN** a new extraction runs

#### Scenario: Fallo no cacheado
- **GIVEN** the extraction for A failed or returned nothing
- **WHEN** the Mix of A is requested again
- **THEN** a new extraction runs

### Requirement: Historial de todo lo que suena
The system SHALL add to the playback history every music track that starts playing, whatever started it (a tap, a list, the queue advancing, the radio, next or previous), SHALL NOT add podcast episodes, and SHALL NOT add a track when it is already the most recent history entry. Local history SHALL be on by default and only off when the user turns it off in Settings.

#### Scenario: Historial activado por defecto
- **GIVEN** a fresh install where the user never touched the history setting
- **WHEN** a music track starts
- **THEN** it becomes the most recent history entry

#### Scenario: Avance automático
- **GIVEN** a list is playing
- **WHEN** the next track starts by itself
- **THEN** that track becomes the most recent history entry

#### Scenario: Repetición o reintento
- **GIVEN** the most recent history entry is A
- **WHEN** A starts playing again
- **THEN** no new entry is added

#### Scenario: Episodio
- **WHEN** a podcast episode starts playing
- **THEN** the history does not change

#### Scenario: Restaurar sesión
- **WHEN** the app restores the last track at launch without playing it
- **THEN** the history does not change

### Requirement: Escuchado hace poco
The system SHALL show on Home "Escuchado hace poco" with the ten most recent distinct tracks of the history, newest first, as compact rows (small square artwork, title, artist).

#### Scenario: Pistas repetidas
- **GIVEN** the history is A, B, A, C (newest first)
- **WHEN** Home is shown
- **THEN** the section lists A, B, C

#### Scenario: Sin historial
- **GIVEN** the history is empty
- **WHEN** Home is shown
- **THEN** the section is not shown

### Requirement: Descubrimiento con filtros
The system SHALL show on Home a "Descubrimiento" section with four groups of chips (Género, Vibra, Década, País), at most one selected per group, and a "Buscar" action that is enabled only when at least one chip is selected. Buscar SHALL search with the selected values joined in the order género, vibra, década, país and list up to 20 songs (no channels) as compact rows with "Reproducir todo". No LLM is used.

#### Scenario: Componer la búsqueda
- **GIVEN** Género "Reggaetón", Década "2010s" and País "Colombia" are selected
- **WHEN** the user taps "Buscar"
- **THEN** the query is "reggaetón 2010s colombia" and up to 20 songs are listed

#### Scenario: Un chip por grupo
- **GIVEN** Vibra "Chill" is selected
- **WHEN** the user taps Vibra "Fiesta"
- **THEN** only "Fiesta" is selected in Vibra; tapping it again leaves Vibra without selection

#### Scenario: Nada seleccionado
- **GIVEN** no chip is selected
- **THEN** "Buscar" is disabled

#### Scenario: Sin resultados o fallo
- **WHEN** the search returns nothing or fails
- **THEN** the section shows "Sin resultados" or a sanitized error and keeps the chips

### Requirement: Composición de Inicio
Home SHALL show, in this order and each only when it has content: Continuar, Selecciones rápidas, Escuchado hace poco, Descubrimiento, Tus podcasts, Favoritos. Home SHALL NOT show Novedades (most popular videos), Artistas destacados or Más escuchadas.

#### Scenario: Secciones retiradas
- **WHEN** Home is shown
- **THEN** no "Artistas destacados", "Más escuchadas" or most-popular section appears
