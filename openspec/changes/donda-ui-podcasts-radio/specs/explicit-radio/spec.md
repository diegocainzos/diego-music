# Especificación: radio explícita

## ADDED Requirements

### Requirement: Radio solo bajo demanda
Playing a track MUST NOT modify the queue beyond the selected context; radio SHALL start only when the user taps «Iniciar radio» in the expanded player, replacing the items after the current track, and SHALL stop with «Radio activa · parar», restoring the original following items when available.

#### Scenario: Reproducir un álbum
- **WHEN** the user plays a track from an album
- **THEN** the queue contains only the album's following tracks and no extra items are appended

#### Scenario: Iniciar radio
- **WHEN** the user taps «Iniciar radio» on a playing track
- **THEN** the current track keeps playing uninterrupted and the upcoming queue is replaced by the radio items

#### Scenario: Radio no disponible
- **WHEN** the resolver returns no radio items or an error
- **THEN** a sanitized message «Radio no disponible para esta pista» is shown and the queue is unchanged

### Requirement: Endpoint de radio en el resolutor
The resolver SHALL expose `GET /v1/radio/{video_id}` protected by the API token, validate `video_id` with the existing rule, build the YouTube Mix URL server-side, run `yt-dlp --flat-playlist` without shell and with the configured timeout, and return at most 30 items `{id, title, channel, duration_seconds}` excluding the seed and invalid IDs; it MUST NOT return upstream URLs, headers or raw errors.

#### Scenario: ID inválido
- **WHEN** a client requests `/v1/radio/` with an ID that fails validation
- **THEN** the service responds 422 without running `yt-dlp`

#### Scenario: Fallo de yt-dlp
- **WHEN** `yt-dlp` fails or times out
- **THEN** the service responds 502 with a generic sanitized message

### Requirement: Sin radio basada en búsquedas
The client MUST NOT generate radio from YouTube Data API searches; `fetchRelatedRadio` and the automatic radio trigger SHALL be removed.

#### Scenario: Cuota
- **WHEN** the user plays twenty tracks in a row without tapping «Iniciar radio»
- **THEN** no YouTube Data API search requests are made for radio
