## Context

DiegoMusic is an Apple-platform native music client. The current UI uses a standard list and card layout. This design overhaul brings an atmospheric Ambient Dark / Glassmorphism aesthetic inspired by modern music player explorations, featuring a circular halo progress scrubber wrapping the album artwork, a clean header, and unified theme options.

## Goals / Non-Goals

**Goals:**
- Implement a circular progress ring wrapping the album artwork with interactive seek touch gesture and ambient light glow.
- Provide a modern, clean header in the expanded player with a collapse button (`chevron.down`), lyrics button (`quote.bubble`), and 3-dots action menu (`ellipsis.circle`), preserving all context actions.
- Position the track title, channel subtitle, and like toggle (`heart` / `heart.fill`) in a clean horizontal layout.
- Introduce an elevated, high-contrast Play/Pause button in the central playback console with previous/next and shuffle/repeat.
- Introduce the *Midnight Indigo* theme mode (`#131836` to `#1A2247`) alongside Dark, Light, and System modes.
- Present the playback queue with artwork thumbnails, track metadata, right-aligned duration, active track accent highlighting, and smooth animated reordering without row numbers.

**Non-Goals:**
- Changing audio backend streaming protocols or AVPlayer engine architecture.
- Removing Web or Android parity (UI patterns will be shared).

## Decisions

### 1. Circular Halo Progress Scrubber (SwiftUI)
- **Geometry**: The artwork container (e.g. 240x240pt) is centered inside a 270x270pt circular ring area.
- **Track & Progress Rings**:
  - Inactive ring: `Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)`.
  - Active progress ring: `Circle().trim(from: 0, to: player.progress).stroke(AngularGradient(...), style: StrokeStyle(lineWidth: 4, lineCap: .round))`.
  - Ambient halo: A duplicate progress ring blurred by `radius: 10` for depth.
- **Touch Gesture Interaction**: `DragGesture(minimumDistance: 0)` computes `atan2(y - cy, x - cx)` to determine the touch angle and updates `player.seek(to: progress)`.
- **Time Indicators**: Elapsed time (`01:24`) and total/remaining time (`-03:45`) placed cleanly below the artwork halo.

### 2. Header & Action Retention
- Header contains `Button(chevron.down)` on the leading side, an empty center (no "REPRODUCIENDO AHORA"), and trailing actions (`quote.bubble` for lyrics sheet, `ellipsis.circle` for the full context menu: Go to Artist, Go to Album, Add to Playlist, Save Album).

### 3. Midnight Indigo Theme Mode
- Added to `AppThemeMode` enum: `.midnight` (or `.indigo`).
- Semantic colors adapt:
  - Background: Gradient from `#131836` to `#1A2247`.
  - Accent: Vibrant `#3E7BFA` (Cobalt) / `#4CC9F0` (Cyan).
  - Surfaces: `.ultraThinMaterial` with border `white.opacity(0.08)`.

### 4. Queue Presentation
- List rows display:
  - 44x44pt thumbnail with 8pt continuous corner radius.
  - Title and Channel with active playback accent tint and audio wave indicator.
  - Duration string right-aligned in tabular monospaced digits.
  - Drag-to-reorder gesture and tap-to-play with spring animation.

## Risks / Trade-offs

- **[Touch precision on circular scrubber]** → Mitigation: Generous hit testing zone (ring padding of 24pt) and immediate visual feedback with time preview during scrubbing.
- **[Small screen fit (iPhone SE / mini)]** → Mitigation: Flexible sizing with `GeometryReader` and `ViewThatFits` / responsive padding so the artwork scales down gracefully.
