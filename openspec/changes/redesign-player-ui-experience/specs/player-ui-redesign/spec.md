## ADDED Requirements

### Requirement: Circular Halo Progress Scrubber
The expanded player view SHALL display an interactive circular halo progress ring closely surrounding a circular-clipped hero album artwork disc that reflects the current playback progress and supports circular scrub gestures.

#### Scenario: Visual presentation of circular progress halo and circular artwork
- **WHEN** a track is playing or paused in the expanded player
- **THEN** the system renders the album artwork clipped to a circle centered inside a matching circular progress ring with active stroke and ambient glow

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
