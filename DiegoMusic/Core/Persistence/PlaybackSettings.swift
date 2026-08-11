import Combine
import Foundation

@MainActor
final class PlaybackSettings: ObservableObject {
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

    @Published private(set) var restoreState: (item: MediaItem, seconds: Double)?

    private let libraryStore: LibraryStore
    private static let historyPreferenceKey = "playback.historyEnabled"
    private static let continuePlaybackPreferenceKey = "playback.continuePlaybackEnabled"
    private static let restoreStatePreferenceKey = "playback.restoreState"

    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
        historyEnabled = libraryStore.preference(for: Self.historyPreferenceKey) == "true"
        continuePlaybackEnabled = libraryStore.preference(for: Self.continuePlaybackPreferenceKey) == "true"
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

    func clearRestoreState() {
        try? libraryStore.setPreference("", for: Self.restoreStatePreferenceKey)
        restoreState = nil
    }
}

private struct RestoreState: Codable {
    let videoID: String
    let title: String
    let channelTitle: String
    let thumbnailURLString: String?
    let seconds: Double
}
