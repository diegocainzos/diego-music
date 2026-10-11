# Especificación: cliente web

## ADDED Requirements

### Requirement: Interfaz Donda compartida
The web client SHALL use the same Donda tokens, black and white themes, monospaced uppercase labels, condensed titles, radius 0 and 1 px borders as the native apps, and SHALL mirror their structure: login gate, Inicio, Buscar and Biblioteca, a floating mini-player and an expanded player.

#### Scenario: Móvil
- **WHEN** the viewport is narrower than 900 px
- **THEN** the three sections are shown in a bottom tab bar and the mini-player floats above it

#### Scenario: Escritorio
- **WHEN** the viewport is 900 px or wider
- **THEN** the sections are listed in a left sidebar like the iPad/macOS app

### Requirement: Sin secretos en el navegador
The web client MUST NOT embed API keys or the resolver's static token; every call to `/api/v1` and `/v1` SHALL use the logged-in user's JWT.

#### Scenario: Reproducir
- **WHEN** a logged-in user plays a track
- **THEN** the browser calls `POST /v1/audio/resolve` with the user's JWT and plays the returned opaque stream URL

### Requirement: Descarga del APK
The web SHALL offer a «DESCARGAR APK» button on the login gate, on Inicio and in Ajustes that downloads `/downloads/diegomusic.apk`.

#### Scenario: Descargar desde el móvil
- **WHEN** an Android user taps «DESCARGAR APK»
- **THEN** the browser downloads `diegomusic.apk` served with the Android package content type
