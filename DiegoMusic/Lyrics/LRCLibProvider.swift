import Foundation

// MARK: - LRCLIB API Response

struct LRCLibResponse: Codable, Sendable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Int
    let instrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?
}

// MARK: - Lyrics Result

enum LyricsResult: Equatable, Sendable {
    case synced([LyricsLine])
    case plain(String)
    case instrumental
    case notFound
}

// MARK: - LRC Parser

enum LRCParser {
    /// Parses an LRC-formatted string into an array of `LyricsLine` sorted by time.
    ///
    /// Accepts `[mm:ss.xx]` and `[mm:ss.xxx]` timestamp formats.
    /// Calculates `endTime` for each line as the `startTime` of the following line.
    static func parse(_ lrcString: String) -> [LyricsLine] {
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\]\s?(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var lines: [(time: Double, text: String)] = []

        for rawLine in lrcString.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let range = NSRange(trimmed.startIndex..., in: trimmed)

            guard let match = regex.firstMatch(in: trimmed, range: range) else { continue }

            func group(_ i: Int) -> String {
                guard let r = Range(match.range(at: i), in: trimmed) else { return "" }
                return String(trimmed[r])
            }

            let minutes = Double(group(1)) ?? 0
            let seconds = Double(group(2)) ?? 0
            let fractionStr = group(3)
            let fraction: Double
            if fractionStr.count == 3 {
                fraction = (Double(fractionStr) ?? 0) / 1000.0
            } else {
                fraction = (Double(fractionStr) ?? 0) / 100.0
            }
            let time = minutes * 60.0 + seconds + fraction
            let text = group(4)

            lines.append((time: time, text: text))
        }

        lines.sort { $0.time < $1.time }

        return lines.enumerated().map { index, line in
            let endTime: Double? = index + 1 < lines.count ? lines[index + 1].time : nil
            return LyricsLine(
                text: line.text,
                startTime: line.time,
                endTime: endTime
            )
        }
    }
}

// MARK: - Title Cleaner

enum TrackMetadataExtractor {
    /// Cleans noisy YouTube channel names (e.g. "Coldplay - Topic" -> "Coldplay", "LadyGagaVEVO" -> "Lady Gaga").
    static func cleanChannel(_ channel: String) -> String {
        var result = channel.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip "- Topic" or " Topic"
        if let topicRegex = try? NSRegularExpression(pattern: #"\s*-\s*Topic$"#, options: .caseInsensitive) {
            result = topicRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        if let topicRegex2 = try? NSRegularExpression(pattern: #"\s+Topic$"#, options: .caseInsensitive) {
            result = topicRegex2.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // Strip "VEVO", "Official", "Music", "Channel" suffix
        if let suffixRegex = try? NSRegularExpression(pattern: #"(VEVO|Official|Music|Channel)$"#, options: .caseInsensitive) {
            result = suffixRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Split CamelCase if single word without spaces (e.g. LadyGaga -> Lady Gaga, TaylorSwift -> Taylor Swift)
        if !result.contains(" ") && result.count > 3 {
            if let camelRegex = try? NSRegularExpression(pattern: #"([a-z])([A-Z])"#) {
                result = camelRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1 $2")
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cleans common tags, video artifacts, and featured artist noise from video titles.
    static func cleanTitle(_ title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove straight and curly quotes
        result = result.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .replacingOccurrences(of: "‘", with: "")
            .replacingOccurrences(of: "’", with: "")

        // Remove parenthesized / bracketed / curled noise tags (English and Spanish)
        let bracketNoisePattern = #"[\(\[\{][^\)\]\}]*(?:official|oficial|video|audio|lyric|letra|remaster|videoclip|visuali[sz]er|live|en\s*vivo|directo|4k|8k|hd|hq|1080p|60fps|prod\.?|feat\.?|ft\.?|with)[^\)\]\}]*[\)\]\}]"#
        if let bracketRegex = try? NSRegularExpression(pattern: bracketNoisePattern, options: .caseInsensitive) {
            result = bracketRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // Remove trailing "feat." / "ft." / "with"
        let trailingFeatPattern = #"\s+(?:feat|ft|with)\.?\s+.*$"#
        if let featRegex = try? NSRegularExpression(pattern: trailingFeatPattern, options: .caseInsensitive) {
            result = featRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // Collapse multiple whitespaces
        if let spaceRegex = try? NSRegularExpression(pattern: #"\s+"#) {
            result = spaceRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts `(artistName, trackName)` from a `MediaItem`.
    ///
    /// Cleans `channelTitle` and `title`. If `title` contains a common separator
    /// (` - `, ` — `, ` – `, ` | `, ` • `, ` // `), splits into artist + track
    /// (the artist from the separator takes priority over channelTitle).
    static func extract(from item: MediaItem) -> (artist: String, track: String) {
        let cleanedChannel = cleanChannel(item.channelTitle)
        let cleanedTitle = cleanTitle(item.title)

        // Detect separators: " - ", " — ", " – ", " | ", " • ", " // "
        let separatorPattern = #"\s+(?:[-—–|•]|//)\s+"#
        if let sepRegex = try? NSRegularExpression(pattern: separatorPattern) {
            let range = NSRange(cleanedTitle.startIndex..., in: cleanedTitle)
            if let match = sepRegex.firstMatch(in: cleanedTitle, range: range),
               let matchRange = Range(match.range, in: cleanedTitle) {
                let artistPart = String(cleanedTitle[..<matchRange.lowerBound])
                let trackPart = String(cleanedTitle[matchRange.upperBound...])

                let cleanArtistFromTitle = cleanTitle(cleanChannel(artistPart))
                let cleanTrackFromTitle = cleanTitle(trackPart)

                if !cleanArtistFromTitle.isEmpty && !cleanTrackFromTitle.isEmpty {
                    return (artist: cleanArtistFromTitle, track: cleanTrackFromTitle)
                }
            }
        }

        return (artist: cleanedChannel.isEmpty ? item.channelTitle : cleanedChannel,
                track: cleanedTitle.isEmpty ? item.title : cleanedTitle)
    }
}

// MARK: - LRCLIB Lyrics Provider

actor LRCLibLyricsProvider: LyricsProviding {
    private struct CacheEntry: Sendable {
        let result: LyricsResult
        let timestamp: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private static let cacheTTL: TimeInterval = 30 * 60 // 30 minutes
    private static let requestTimeout: TimeInterval = 10

    private static let userAgent = "AppleMusicClone/1.0 (https://github.com/app)"
    private static let baseURL = "https://lrclib.net/api"

    nonisolated func lyrics(for item: MediaItem, at currentTime: Double) async -> [LyricSegment]? {
        let result = await fetchLyrics(for: item)
        switch result {
        case .synced(let lines):
            return [LyricSegment(lines: lines)]
        case .plain, .instrumental, .notFound:
            return nil
        }
    }

    /// Fetches lyrics with cache, returning the full `LyricsResult`.
    func fetchLyrics(for item: MediaItem) async -> LyricsResult {
        // Check cache
        if let entry = cache[item.id],
           Date().timeIntervalSince(entry.timestamp) < Self.cacheTTL {
            return entry.result
        }

        let result = await performFetch(for: item)
        cache[item.id] = CacheEntry(result: result, timestamp: Date())
        return result
    }

    private func performFetch(for item: MediaItem) async -> LyricsResult {
        let meta = TrackMetadataExtractor.extract(from: item)
        let duration = item.durationSeconds

        // Stage 1: Exact /api/get with duration (if available)
        if let duration, let response = await fetchGet(artist: meta.artist, track: meta.track, duration: duration) {
            let res = processResponse(response)
            if res != .notFound { return res }
        }

        // Stage 2: Exact /api/get without duration
        if let response = await fetchGet(artist: meta.artist, track: meta.track, duration: nil) {
            let res = processResponse(response)
            if res != .notFound { return res }
        }

        // Stage 3: Structured /api/search with artist_name and track_name
        if let response = await fetchSearch(artist: meta.artist, track: meta.track, duration: duration) {
            let res = processResponse(response)
            if res != .notFound { return res }
        }

        // Stage 4: Free-text /api/search with q = "\(artist) \(track)"
        if let response = await fetchSearchQuery(query: "\(meta.artist) \(meta.track)", expectedArtist: meta.artist, expectedTrack: meta.track, duration: duration) {
            let res = processResponse(response)
            if res != .notFound { return res }
        }

        // Stage 5: Fallback search with track name only if artist might have been noisy or channel-based
        if meta.track != item.title {
            if let response = await fetchSearch(artist: nil, track: meta.track, duration: duration) {
                let res = processResponse(response)
                if res != .notFound { return res }
            }
        }

        return .notFound
    }

    private func processResponse(_ response: LRCLibResponse) -> LyricsResult {
        if response.instrumental {
            return .instrumental
        }
        if let synced = response.syncedLyrics, !synced.isEmpty {
            let lines = LRCParser.parse(synced)
            if !lines.isEmpty {
                return .synced(lines)
            }
        }
        if let plain = response.plainLyrics, !plain.isEmpty {
            return .plain(plain)
        }
        return .notFound
    }

    private func fetchGet(artist: String, track: String, duration: Int?) async -> LRCLibResponse? {
        var components = URLComponents(string: "\(Self.baseURL)/get")
        var items = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: track),
        ]
        if let duration {
            items.append(URLQueryItem(name: "duration", value: String(duration)))
        }
        components?.queryItems = items
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode(LRCLibResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private func fetchSearch(artist: String?, track: String, duration: Int?) async -> LRCLibResponse? {
        var components = URLComponents(string: "\(Self.baseURL)/search")
        var queryItems = [URLQueryItem(name: "track_name", value: track)]
        if let artist, !artist.isEmpty {
            queryItems.append(URLQueryItem(name: "artist_name", value: artist))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { return nil }

        return await executeSearchAndSelectBest(url: url, expectedArtist: artist, expectedTrack: track, expectedDuration: duration)
    }

    private func fetchSearchQuery(query: String, expectedArtist: String, expectedTrack: String, duration: Int?) async -> LRCLibResponse? {
        var components = URLComponents(string: "\(Self.baseURL)/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { return nil }

        return await executeSearchAndSelectBest(url: url, expectedArtist: expectedArtist, expectedTrack: expectedTrack, expectedDuration: duration)
    }

    private func executeSearchAndSelectBest(url: URL, expectedArtist: String?, expectedTrack: String, expectedDuration: Int?) async -> LRCLibResponse? {
        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let results = try JSONDecoder().decode([LRCLibResponse].self, from: data)
            guard !results.isEmpty else { return nil }

            return selectBestCandidate(from: results, expectedArtist: expectedArtist, expectedTrack: expectedTrack, expectedDuration: expectedDuration)
        } catch {
            return nil
        }
    }

    private func selectBestCandidate(from results: [LRCLibResponse], expectedArtist: String?, expectedTrack: String, expectedDuration: Int?) -> LRCLibResponse? {
        let expectedTrackLower = expectedTrack.lowercased()
        let expectedArtistLower = expectedArtist?.lowercased()

        var bestMatch: (response: LRCLibResponse, score: Int)?

        for candidate in results {
            var score = 0

            // 1. Synced lyrics preference
            if let synced = candidate.syncedLyrics, !synced.isEmpty {
                score += 100
            } else if let plain = candidate.plainLyrics, !plain.isEmpty {
                score += 30
            } else if candidate.instrumental {
                score += 10
            } else {
                continue // No lyrics or instrumental info
            }

            // 2. Track name match
            let candidateTrackLower = candidate.trackName.lowercased()
            if candidateTrackLower == expectedTrackLower {
                score += 40
            } else if candidateTrackLower.contains(expectedTrackLower) || expectedTrackLower.contains(candidateTrackLower) {
                score += 20
            }

            // 3. Artist name match
            if let expectedArtistLower, !expectedArtistLower.isEmpty {
                let candidateArtistLower = candidate.artistName.lowercased()
                if candidateArtistLower == expectedArtistLower {
                    score += 40
                } else if candidateArtistLower.contains(expectedArtistLower) || expectedArtistLower.contains(candidateArtistLower) {
                    score += 20
                }
            }

            // 4. Duration proximity match (if known)
            if let expectedDuration, expectedDuration > 0 {
                let diff = abs(candidate.duration - expectedDuration)
                if diff <= 3 {
                    score += 30
                } else if diff <= 8 {
                    score += 15
                } else if diff > 60 {
                    score -= 40
                }
            }

            if let currentBest = bestMatch {
                if score > currentBest.score {
                    bestMatch = (candidate, score)
                }
            } else {
                bestMatch = (candidate, score)
            }
        }

        // Only return if candidate achieved a reasonable score threshold
        guard let best = bestMatch, best.score >= 20 else {
            return nil
        }
        return best.response
    }
}
