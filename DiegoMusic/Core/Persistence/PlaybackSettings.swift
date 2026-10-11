import Combine
import Foundation
import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable, Codable {
    case black = "black"
    case white = "white"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "Negro"
        case .white: return "Blanco"
        }
    }

    var icon: String {
        switch self {
        case .black: return "circle.fill"
        case .white: return "circle"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .black: return .dark
        case .white: return .light
        }
    }

    static func migrating(_ raw: String?) -> AppThemeMode {
        guard let raw else { return .black }
        switch raw.lowercased() {
        case "white", "light":
            return .white
        default:
            return .black
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = Self.migrating(raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

@MainActor
final class PlaybackSettings: ObservableObject {
    @Published var themeMode: AppThemeMode {
        didSet {
            try? libraryStore.setPreference(
                themeMode.rawValue,
                for: Self.themeModePreferenceKey
            )
        }
    }

    @Published var historyEnabled: Bool {
        didSet {
            try? libraryStore.setPreference(
                historyEnabled ? "true" : "false",
                for: Self.historyPreferenceKey
            )
        }
    }

    /// "Continuar donde lo dejaste": persiste la pista activa y su posición.
    @Published var continuePlaybackEnabled: Bool {
        didSet {
            try? libraryStore.setPreference(
                continuePlaybackEnabled ? "true" : "false",
                for: Self.continuePlaybackPreferenceKey
            )
        }
    }

    static let allowedPodcastRates: [Float] = [1.0, 1.25, 1.5, 1.75, 2.0]

    @Published var podcastRate: Float {
        didSet {
            try? libraryStore.setPreference(
                String(podcastRate),
                for: Self.podcastRatePreferenceKey
            )
        }
    }

    @Published private(set) var restoreState: (item: MediaItem, seconds: Double)?

    private let libraryStore: LibraryStore
    private static let themeModePreferenceKey = "playback.themeMode"
    private static let historyPreferenceKey = "playback.historyEnabled"
    private static let continuePlaybackPreferenceKey = "playback.continuePlaybackEnabled"
    private static let podcastRatePreferenceKey = "playback.podcastRate"
    private static let restoreStatePreferenceKey = "playback.restoreState"

    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
        let rawTheme = libraryStore.preference(for: Self.themeModePreferenceKey)
        themeMode = AppThemeMode.migrating(rawTheme)
        historyEnabled = libraryStore.preference(for: Self.historyPreferenceKey) == "true"
        continuePlaybackEnabled = libraryStore.preference(for: Self.continuePlaybackPreferenceKey) == "true"
        if let rawRate = libraryStore.preference(for: Self.podcastRatePreferenceKey),
           let parsed = Float(rawRate),
           Self.allowedPodcastRates.contains(where: { abs($0 - parsed) < 0.001 }) {
            podcastRate = parsed
        } else {
            podcastRate = 1.0
        }
        if continuePlaybackEnabled,
           let raw = libraryStore.preference(for: Self.restoreStatePreferenceKey),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(RestoreState.self, from: data) {
            restoreState = (MediaItem(
                id: decoded.videoID,
                title: decoded.title,
                channelTitle: decoded.channelTitle,
                thumbnailURL: decoded.thumbnailURLString.flatMap(URL.init(string:))
            ), decoded.seconds)
        }
    }

    func cyclePodcastRate() {
        if let currentIndex = Self.allowedPodcastRates.firstIndex(where: { abs($0 - podcastRate) < 0.001 }) {
            let nextIndex = (currentIndex + 1) % Self.allowedPodcastRates.count
            podcastRate = Self.allowedPodcastRates[nextIndex]
        } else {
            podcastRate = 1.0
        }
    }

    /// Persiste la pista activa y su posición si el ajuste está activo.
    func persist(item: MediaItem, seconds: Double) {
        guard continuePlaybackEnabled else { return }
        let state = RestoreState(
            videoID: item.id,
            title: item.title,
            channelTitle: item.channelTitle,
            thumbnailURLString: item.thumbnailURL?.absoluteString,
            seconds: seconds
        )
        guard let data = try? JSONEncoder().encode(state),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        try? libraryStore.setPreference(raw, for: Self.restoreStatePreferenceKey)
        restoreState = (item, seconds)
    }
}

private struct RestoreState: Codable {
    let videoID: String
    let title: String
    let channelTitle: String
    let thumbnailURLString: String?
    let seconds: Double
}
