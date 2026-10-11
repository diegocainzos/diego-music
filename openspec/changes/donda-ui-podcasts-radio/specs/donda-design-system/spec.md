# Especificación: sistema de diseño Donda

## ADDED Requirements

### Requirement: Temas Donda negro y blanco
The app SHALL offer exactly two theme modes, `black` (default) and `white`, and SHALL migrate legacy stored values (`midnight`, `dark`, `system` or unknown → `black`; `light` → `white`).

#### Scenario: Usuario con tema Midnight guardado
- **WHEN** the app launches with the stored theme value `midnight`
- **THEN** `PlaybackSettings.themeMode` is `.black`
- **AND** the interface uses a pure black background and light grey text

#### Scenario: Cambiar a blanco
- **WHEN** the user selects «Blanco» in Ajustes
- **THEN** every screen, the mini-player and the expanded player use a pure white background and near-black text without restarting

### Requirement: Lenguaje visual monocromo
The interface SHALL use only the Donda tokens (`background`, `textPrimary`, `textSecondary`, `hairline`, `outline`), corner radius 0, 1 pt borders, system monospaced uppercase text with letter-spacing, and condensed regular-weight titles; it MUST NOT use accent colors, gradients or decorative shadows except the floating mini-player shadow.

#### Scenario: Estado seleccionado
- **WHEN** a chip, segment or primary button is active
- **THEN** it is rendered inverted (filled `textPrimary`, label `background`) instead of using a color accent

#### Scenario: Carátulas
- **WHEN** a list shows a track, album or episode
- **THEN** its real artwork is shown in color inside a square with radius 0 and a `hairline` border

#### Scenario: Sin carátula
- **WHEN** an item has no thumbnail
- **THEN** an empty square filled with `background` and a `hairline` border is shown
