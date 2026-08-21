## Context

DiegoMusic fetches audio and basic track information (`title`, `channelTitle`, `durationSeconds`) from YouTube. Lyrics are retrieved on the client via `LRCLibLyricsProvider` querying the open community LRCLIB API (`https://lrclib.net/api`). Because YouTube uploads are cluttered with channel markers (e.g. `LadyGagaVEVO`, `Coldplay - Topic`, `Queen Official`) and title noise (e.g. `(Official Video Remastered)`, `[4K 60FPS]`, `(feat. DaBaby)`), direct exact `/api/get` and raw query `/api/search` currently return 0 results for most mainstream songs, causing the UI to display "No lyrics available".

## Goals / Non-Goals

**Goals:**
- Dramatically increase the hit rate of synced and plain lyrics for mainstream, indie, and Latin music.
- Clean channel names (remove `- Topic`, `VEVO`, `Official`, etc.) and video titles (remove parenthetical tags, audiovisual descriptors, featured artists).
- Support multiple artist/title separator formats in video titles (` - `, ` — `, ` | `, ` • `, ` // `).
- Implement a tiered fallback strategy for LRCLIB requests (exact get with duration, exact get without duration, structured search, plain query search, track-only search).
- Rank/score candidate search results against track duration and artist similarity to ensure accuracy and prevent wrong song lyrics.

**Non-Goals:**
- Integrating paid or proprietary lyrics APIs (e.g. Musixmatch, Genius scraping, LyricFind) with commercial license requirements.
- Modifying playback queue, audio coordinator, or backend resolver endpoints.

## Decisions

1. **Deterministic Multi-Stage Metadata Extraction**:
   - *Rationale*: Instead of a single regex pass, `TrackMetadataExtractor` will:
     1. Clean channel noise (`- Topic`, `VEVO`, `Official`, `Music`, `Channel`).
     2. Detect artist-title split in title using multiple common separators. If found, both artist and title are extracted and normalized.
     3. Strip parenthesized/bracketed junk in English and Spanish (`official video`, `video oficial`, `audio oficial`, `remaster`, `4k`, `hd`, `live`, `en vivo`, `visualizer`, `prod. by`, `feat./ft.`).
     4. Remove quotes and collapse whitespace.

2. **Cascading LRCLIB Fetching Pipeline**:
   - *Rationale*: Different LRCLIB endpoints have different matching tolerances:
     - Tier 1: `/api/get` with `artist_name`, `track_name`, `duration` (exact match).
     - Tier 2: `/api/get` with `artist_name`, `track_name` (exact match ignoring duration differences).
     - Tier 3: `/api/search` with structured parameters `artist_name` and `track_name`.
     - Tier 4: `/api/search` with `q = "\(artist) \(track)"`.
     - Tier 5: If artist was inferred from channel and failed, `/api/search` with `track_name` or `q = "\(track)"`.

3. **Candidate Scoring & Validation**:
   - *Rationale*: Avoid false positives when using tolerant search:
     - Prioritize items with `syncedLyrics`.
     - Score candidate tracks by duration tolerance (within ±5 to ±10 seconds of `MediaItem.durationSeconds` when available).
     - Verify candidate `artistName` or `trackName` contains key tokens of the searched song.

## Risks / Trade-offs

- [Risk] Aggressive title cleaning might strip legitimate parenthesized song titles (e.g., songs genuinely titled `"Song (Part 2)"` or `"All Too Well (10 Minute Version)"`).
  → *Mitigation*: Only strip parenthetical groups containing specific noise keywords (`official`, `video`, `audio`, `remaster`, `4k`, `live`, `feat`, `prod`, `clip`, etc.), preserving musical qualifiers like `(Part 1)`, `(Acoustic)`, `(Radio Edit)`.
- [Risk] Multiple HTTP calls to LRCLIB could increase latency.
  → *Mitigation*: Stop immediately at the first tier that returns a valid match; in-memory caching with 30-minute TTL prevents duplicate requests.
