## ADDED Requirements

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
The system SHALL show on Home a "Selecciones rápidas" section built from the YouTube Mix of the most recently played track, excluding that track, as a compact list where each row shows small square artwork, the title as the prominent text and the artist as secondary text, with a "Reproducir todo" action.

#### Scenario: Con historial
- **GIVEN** the most recently played track is A
- **WHEN** Home is shown
- **THEN** "Selecciones rápidas" lists the Mix items of A without A

#### Scenario: Reproducir una fila
- **WHEN** the user taps a row in "Selecciones rápidas"
- **THEN** that track plays as a single track

#### Scenario: Reproducir todo
- **WHEN** the user taps "Reproducir todo"
- **THEN** the queue becomes the listed tracks starting at the first one and the radio is not active

#### Scenario: Sin historial o sin Mix
- **GIVEN** there is no history, or the Mix request fails or returns nothing
- **WHEN** Home is shown
- **THEN** the "Selecciones rápidas" section is not shown and no error is displayed

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
