## 1. Theme System Updates

- [x] 1.1 Update `AppThemeMode` and `PlaybackSettings` to include `.midnight` alongside `.dark`, `.light`, and `.system`
- [x] 1.2 Extend `DiegoTheme` with Midnight Indigo palette tokens, gradients, and semantic glassmorphic card styles
- [x] 1.3 Update `SettingsView` appearance picker with the new theme option

## 2. Expanded Player Redesign

- [x] 2.1 Build the interactive `CircularHaloScrubber` component with circular progress stroke, ambient halo blur, and touch/drag seek gesture
- [x] 2.2 Redesign `expandedPlayerSheet` in `PlayerDock.swift`:
  - Create the top header with collapse chevron, lyrics button (`quote.bubble`), and 3-dots action menu (`ellipsis.circle`) without "REPRODUCIENDO AHORA"
  - Embed the hero artwork inside the circular halo scrubber with elapsed and remaining time labels
  - Implement the track title, channel link, and quick favorite heart toggle row
  - Refactor the 5-button playback console featuring the elevated high-contrast Play/Pause circular disc
  - Embed bottom utility buttons (queue sheet trigger and AirPlay picker)

## 3. Queue Presentation Redesign

- [x] 3.1 Refactor the playback queue section in `PlayerDock.swift` to display album thumbnails, track titles, artist names, right-aligned duration strings, active playing indicators, and smooth reordering without row numbers

## 4. Verification and Validation

- [x] 4.1 Run `./scripts/verify-no-secrets.py` and Swift unit tests
- [x] 4.2 Verify interactive circular seek, theme switching, and queue selection in macOS/iOS simulator build
