## ADDED Requirements

### Requirement: Refined Playback Queue Presentation
The queue view SHALL display queued items with artwork thumbnails, track title, channel subtitle, right-aligned duration, active track accent highlighting, and smooth drag-and-drop or animated selection without displaying row index numbers.

#### Scenario: Queue item display without row numbers
- **WHEN** the playback queue is displayed
- **THEN** each track row renders its thumbnail, title, channel name, and duration string on the right edge, without displaying index numbers

#### Scenario: Active track distinction in queue
- **WHEN** a track is currently playing in the queue
- **THEN** its row is highlighted with the theme accent color and an animated sound indicator
