# Especificación: Smart Queue & Play Next

## ADDED Requirements

### Requirement: Encolado prioritario (`enqueueNext`)
The `PlaybackQueue` SHALL support inserting a item immediately after the current playing item.

#### Scenario: Insert item after current active track
- Given a `PlaybackQueue` with a current active track at `currentIndex`.
- When `enqueueNext(item)` is called with a new `item`.
- Then `item` is inserted at index `currentIndex + 1`.
- And existing subsequent items are shifted down by one position.

#### Scenario: Reordering existing item to play next
- Given a `PlaybackQueue` containing `item` at a later index.
- When `enqueueNext(item)` is called.
- Then `item` is moved to `currentIndex + 1` without duplicating the track.

### Requirement: Cola automática inteligente de radio
The system SHALL auto-generate a background radio queue of ~15 related items when a track starts playing.

#### Scenario: Auto-generating radio queue on track playback
- Given a `MediaItem` played by the user.
- When `play(item)` is executed in `AudioPlayerCoordinator`.
- Then a background task fetches ~15 related items combining top tracks from the same artist and related style artists.
- And those items are appended to `PlaybackQueue` without interrupting active playback.
