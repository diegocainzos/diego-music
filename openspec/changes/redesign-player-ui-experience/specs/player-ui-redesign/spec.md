## ADDED Requirements

### Requirement: Circular Halo Progress Scrubber
The expanded player view SHALL display an interactive circular halo progress ring around the hero album artwork that reflects the current playback progress and supports circular scrub gestures.

#### Scenario: Visual presentation of circular progress halo
- **WHEN** a track is playing or paused
- **THEN** the system renders a circular progress stroke around the artwork container with active progress proportion and ambient blur halo

#### Scenario: Interactive circular seek gesture
- **WHEN** the user touches or drags around the circular progress ring
- **THEN** the system calculates the progress angle, updates the displayed time preview, and seeks AVPlayer to the target timestamp upon release

### Requirement: Modernized Expanded Player Header
The expanded player view SHALL provide a top navigation header with a dismiss button on the leading edge, a lyrics button and a 3-dots context menu on the trailing edge, and NO "REPRODUCIENDO AHORA" label.

#### Scenario: Header navigation and actions
- **WHEN** the expanded player is open
- **THEN** the leading button dismisses the sheet, the lyrics button opens the live lyrics view, and the context menu displays "Ir al artista", "Ir al álbum", "Añadir a playlist", and "Salvar álbum"

### Requirement: Track Information and Like Row
The expanded player view SHALL present the track title, channel title, and a favorite toggle button in a unified layout row.

#### Scenario: Toggling favorite status from expanded player
- **WHEN** the user taps the heart button on the track info row
- **THEN** the track favorite state toggles in the library store and updates the heart icon appearance immediately
