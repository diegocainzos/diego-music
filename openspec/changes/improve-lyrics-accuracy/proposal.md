## Why

Currently, lyrics in DiegoMusic fail to load for the vast majority of tracks (even worldwide hits from artists like Queen, Lady Gaga, Dua Lipa, or Coldplay). The root cause is metadata mismatch: YouTube video titles and channel names contain heavy noise (e.g., `- Topic`, `VEVO`, `(Official Music Video)`, `(Remastered 2021)`, `(Video Oficial)`), while the LRCLIB API relies on clean artist/track metadata or full-text query matching. When queries contain junk tokens, LRCLIB returns zero search results and falls back directly to "Not Found".

Improving track metadata normalization and adopting a multi-tier, tolerant querying and candidate scoring strategy against LRCLIB will drastically increase the lyrics hit rate without adding proprietary, paid scraping services.

## What Changes

- **Enhanced YouTube Metadata Normalization**: Comprehensive cleaning of channel titles (stripping `- Topic`, `VEVO`, `Official`, `Music`, `Channel`, etc.) and video titles (stripping English & Spanish tags like `(Official Video)`, `(Video Oficial)`, `(Audio)`, `(Remastered ...)`, `[4K]`, `(En Vivo)`, `(feat. ...)`).
- **Multi-Separator Track Extraction**: Parsing artist and title from diverse YouTube separators (` - `, ` — `, ` | `, ` • `, ` // `).
- **Multi-Stage LRCLIB Query Pipeline**:
  1. Exact `/api/get` with clean artist, track, and duration.
  2. Exact `/api/get` with clean artist and track.
  3. Structured `/api/search` with `track_name` and `artist_name`.
  4. Free-text `/api/search` with `q = "\(artist) \(track)"`.
  5. Fallback `/api/search` with `track_name` only when artist is ambiguous.
- **Candidate Scoring & Duration Validation**: Filtering and scoring search results against `MediaItem.durationSeconds` (when available) and artist similarity to ensure accuracy and avoid false positives while maximizing synced lyrics availability.

## Capabilities

### New Capabilities
- `lyrics-matching`: Multi-tier metadata cleaning, resilient cascading queries, and candidate scoring for LRCLIB integration.

### Modified Capabilities
<!-- No modified specs in openspec/specs/ -->

## Impact

- `DiegoMusic/Lyrics/LRCLibProvider.swift`: Metadata extraction logic (`TrackMetadataExtractor`) and fetching pipeline (`LRCLibLyricsProvider`).
- Improved user experience with real-time synced lyrics for the vast majority of popular songs in DiegoMusic.
