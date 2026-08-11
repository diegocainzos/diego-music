import Foundation

/// Caché en memoria para resultados de búsqueda con TTL (24 horas por defecto).
///
/// Normaliza la consulta (insensible a mayúsculas, tildes y espacios duplicados)
/// para evitar peticiones redundantes a la API de YouTube o al VPS Resolver.
actor SearchCache {
    struct Entry: Sendable {
        let page: SearchPage
        let timestamp: Date
    }

    private var storage: [String: Entry] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 24 * 60 * 60) {
        self.ttl = ttl
    }

    /// Obtiene una página de búsqueda cacheada si no ha caducado.
    func get(for query: String) -> SearchPage? {
        let key = normalize(query)
        guard let entry = storage[key] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) < ttl {
            return entry.page
        } else {
            storage.removeValue(forKey: key)
            return nil
        }
    }

    /// Guarda una página de búsqueda en la caché.
    func set(_ page: SearchPage, for query: String) {
        let key = normalize(query)
        storage[key] = Entry(page: page, timestamp: Date())
    }

    /// Limpia la caché por completo.
    func clear() {
        storage.removeAll()
    }

    /// Normaliza la consulta: "Coldplay - Yellow  " -> "coldplay - yellow"
    private func normalize(_ query: String) -> String {
        query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}
