## ADDED Requirements

### Requirement: Refined Playback Queue Presentation
The queue view SHALL display queued items floating directly on the ambient background without outer card containers or section headers, presenting each track with a rounded thumbnail, vertically centered title and artist metadata, and right-aligned duration.

#### Scenario: Floating track list rows without outer cards or headers
- **WHEN** the user views the playback queue in the expanded player
- **THEN** the tracks render as vertical floating rows without a "A continuación" box, without song count badges, and without swipe instruction text

#### Scenario: Track item row structure
- **WHEN** a track is rendered in the queue list
- **THEN** it displays a rounded thumbnail on the left, vertically centered title and artist, and duration on the right

#### Scenario: Active track distinction in queue
- **WHEN** a track is currently playing in the queue
- **THEN** its row is highlighted with a subtle accent tint and a playing sound indicator
