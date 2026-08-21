## Why

The current player interface and visual themes in DiegoMusic follow a functional layout, but require a modern, immersive ambient experience with high-fidelity glassmorphism, responsive circular halo progress ring around album artwork, unified theme modes (introducing *Midnight Indigo* alongside Dark and Light), and a refined queue list view.

## What Changes

- **Midnight Indigo Theme**: Adds a rich ambient dark theme (`#131836` to `#1A2247`) with cobalt/cyan accents (`#3E7BFA`), glassmorphic translucency (`.ultraThinMaterial`), and adaptive palette support alongside Dark, Light, and System modes.
- **Modern Expanded Player Layout**:
  - Top header with circular translucent collapse button (`chevron.down`), lyrics button (`quote.bubble`), and 3-dots action menu (`ellipsis.circle`) preserving all existing capabilities (go to artist, go to album, add to playlist, save album). No "REPRODUCIENDO AHORA" title.
  - Hero album artwork wrapped in an interactive circular halo progress ring (`Circle().stroke(...)` / `Circle().trim(...)` with ambient glow and touch scrubbing).
  - High-contrast track information row with track title, artist subtitle, and quick favorite toggle (`heart` / `heart.fill`).
  - 5-button playback console featuring an elevated high-contrast white circular Play/Pause disc (`pause.fill` / `play.fill`) and shuffle/previous/next/repeat controls.
  - Bottom utility actions for queue presentation and AirPlay device routing.
- **Refined Queue View**:
  - Displays queued tracks with album thumbnail, title, channel/artist, duration on the right, active track accent highlighting, and smooth animated reordering without row index numbers.

## Capabilities

### New Capabilities
- `player-ui-redesign`: Immersive expanded player with interactive circular halo progress around artwork, clean header controls, elevated play/pause disc, and bottom utility actions.
- `app-theme-system`: Midnight Indigo ambient theme mode integrated alongside Dark, Light, and System modes with consistent tokens.
- `queue-ui-redesign`: Modernized queue presentation with thumbnail, track metadata, right-aligned duration, active track accent glow, and animated reordering.

### Modified Capabilities
<!-- None -->

## Impact

- **SwiftUI Views**: `DiegoMusic/Features/Player/PlayerDock.swift`, `DiegoMusic/Design/DesignSystem.swift`, `DiegoMusic/Core/Persistence/PlaybackSettings.swift`, `DiegoMusic/Features/Settings/SettingsView.swift`.
- **User Experience**: Richer visual hierarchy, interactive circular scrubbing, smoother queue inspection, and ambient mood lighting.
