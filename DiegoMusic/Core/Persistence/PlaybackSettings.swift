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

    private let libraryStore: LibraryStore
    private static let historyPreferenceKey = "playback.historyEnabled"

    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
        historyEnabled = libraryStore.preference(for: Self.historyPreferenceKey) == "true"
    }

    func clearHistory() throws {
        try libraryStore.clearHistory()
    }
}
