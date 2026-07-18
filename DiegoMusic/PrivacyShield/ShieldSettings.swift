import Combine
import Foundation

@MainActor
final class ShieldSettings: ObservableObject {
    @Published var mode: ShieldMode {
        didSet { try? libraryStore.setPreference(mode.rawValue, for: Self.preferenceKey) }
    }

    @Published var customRulesData: Data?
    private let libraryStore: LibraryStore
    private static let preferenceKey = "privacyShield.mode"

    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
        mode = ShieldMode(rawValue: libraryStore.preference(for: Self.preferenceKey) ?? "") ?? .balanced
    }

    func importRules(from url: URL, loader: FilterListLoader = FilterListLoader()) throws {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        _ = try loader.validateCustomList(data)
        customRulesData = data
    }

    func clearCustomRules() {
        customRulesData = nil
    }
}
