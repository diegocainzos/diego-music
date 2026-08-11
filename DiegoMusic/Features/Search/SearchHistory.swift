import Combine
import Foundation

/// Almacén ligero de consultas de búsqueda recientes, persistido en el
/// `PreferenceRecord` existente (JSON en la clave `search.recentQueries`) a
/// través de `LibraryStore`. Sin modelos Core Data nuevos ni migraciones.
@MainActor
final class SearchHistory {
    static let storageKey = "search.recentQueries"
    private static let maxEntries = 10

    @Published private(set) var recentQueries: [String] = []

    private let libraryStore: LibraryStore

    init(libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
        load()
    }

    /// Inserta una consulta al frente del historial, deduplicándola y
    /// recortando al máximo de entradas. No guarda consultas vacías.
    func record(_ query: String) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        recentQueries.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        recentQueries.insert(normalized, at: 0)
        if recentQueries.count > Self.maxEntries {
            recentQueries = Array(recentQueries.prefix(Self.maxEntries))
        }
        persist()
    }

    private func load() {
        guard let raw = libraryStore.preference(for: Self.storageKey),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            recentQueries = []
            return
        }
        recentQueries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(recentQueries),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        try? libraryStore.setPreference(raw, for: Self.storageKey)
    }
}
