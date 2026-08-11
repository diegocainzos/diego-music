import Combine
import Foundation
import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable, Codable {
    case dark = "dark"
    case light = "light"
    case system = "system"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Oscuro"
        case .light: return "Claro"
        case .system: return "Sistema"
        }
    }

    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.righthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
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

    @Published private(set) var restoreState: (item: MediaItem, seconds: Double)?

    private let libraryStore: LibraryStore
    private static let themeModePreferenceKey = "playback.themeMode"
    private static let historyPreferenceKey = "playback.historyEnabled"
    private static let continuePlaybackPreferenceKey = "playback.continuePlaybackEnabled"
    private static let restoreStatePreferenceKey = "playback.restoreState"

    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
        let rawTheme = libraryStore.preference(for: Self.themeModePreferenceKey)
        themeMode = AppThemeMode(rawValue: rawTheme ?? "") ?? .dark
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
