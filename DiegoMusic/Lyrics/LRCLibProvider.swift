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
    /// Patterns to strip from YouTube video titles to extract the clean track name.
    private static let stripPatterns: [String] = [
        #"\s*\(Official\s*(Music\s*)?Video\)"#,
        #"\s*\[Official\s*(Music\s*)?Video\]"#,
        #"\s*\(Official\s*Audio\)"#,
        #"\s*\[Official\s*Audio\]"#,
        #"\s*\(Lyrics?\)"#,
        #"\s*\[Lyrics?\]"#,
        #"\s*\(Audio\)"#,
        #"\s*\[Audio\]"#,
        #"\s*\(HD\)"#,
        #"\s*\[HD\]"#,
        #"\s*\(HQ\)"#,
        #"\s*\(Visuali[sz]er\)"#,
        #"\s*\[Visuali[sz]er\]"#,
        #"\s*\(Lyric\s*Video\)"#,
        #"\s*\[Lyric\s*Video\]"#,
        #"\s*\(Live\)"#,
        #"\s*ft\.?\s+.*$"#,
        #"\s*feat\.?\s+.*$"#,
    ]

    /// Extracts `(artistName, trackName)` from a `MediaItem`.
    ///
    /// Uses `channelTitle` as artist. Cleans `title` by stripping common
    /// YouTube suffixes. If title contains ` - `, splits into artist + track
    /// (the artist from the dash takes priority over channelTitle).
    static func extract(from item: MediaItem) -> (artist: String, track: String) {
        var title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip common suffixes (case-insensitive)
        for pattern in stripPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                title = regex.stringByReplacingMatches(
                    in: title,
                    range: NSRange(title.startIndex..., in: title),
                    withTemplate: ""
                )
            }
        }

        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // If title contains " - ", split into artist and track
        if let dashRange = title.range(of: " - ") {
            let artist = String(title[title.startIndex..<dashRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let track = String(title[dashRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !artist.isEmpty && !track.isEmpty {
                return (artist: artist, track: track)
            }
        }

        return (artist: item.channelTitle, track: title)
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

        // Try /api/get first
        if let response = await fetchGet(artist: meta.artist, track: meta.track) {
            return processResponse(response)
        }

        // Fallback to /api/search
        if let response = await fetchSearch(artist: meta.artist, track: meta.track) {
            return processResponse(response)
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

    private func fetchGet(artist: String, track: String) async -> LRCLibResponse? {
        var components = URLComponents(string: "\(Self.baseURL)/get")
        components?.queryItems = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: track),
        ]
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

    private func fetchSearch(artist: String, track: String) async -> LRCLibResponse? {
        let query = "\(artist) \(track)"
        var components = URLComponents(string: "\(Self.baseURL)/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let results = try JSONDecoder().decode([LRCLibResponse].self, from: data)

            // Prefer results with synced lyrics
            if let synced = results.first(where: { $0.syncedLyrics != nil && !($0.syncedLyrics?.isEmpty ?? true) }) {
                return synced
            }
            // Fall back to first result with plain lyrics
            if let plain = results.first(where: { $0.plainLyrics != nil && !($0.plainLyrics?.isEmpty ?? true) }) {
                return plain
            }
            return nil
        } catch {
            return nil
        }
    }
}
