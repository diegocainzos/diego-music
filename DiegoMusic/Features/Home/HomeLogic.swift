import Foundation

enum DiscoveryChips {
    static let genre = ["Pop", "Rock", "Hip hop", "Reggaetón", "Reggae", "Electrónica", "House", "Techno", "Drum and bass", "Dubstep", "Trance", "Indie", "R&B", "Jazz", "Flamenco", "Clásica"]
    static let vibe = ["Chill", "Fiesta", "Triste", "Energía", "Romántica", "Concentración"]
    static let decade = ["70s", "80s", "90s", "2000s", "2010s", "2020s"]
    static let country = ["España", "Galicia", "México", "Argentina", "Colombia", "USA", "UK", "Brasil", "Corea", "Japón", "Francia"]
}

enum HomeLogic {
    /// Pistas más recientes primero, una por id.
    static func distinctRecent(_ history: [MediaItem], limit: Int = 10) -> [MediaItem] {
        var seen = Set<String>()
        var result: [MediaItem] = []
        for item in history where seen.insert(item.id).inserted {
            result.append(item)
            if result.count == limit { break }
        }
        return result
    }

    static func looksLikeSong(_ title: String) -> Bool {
        if title.filter({ $0 == "," }).count >= 3 { return false }
        // Minúsculas + límites Unicode explícitos: igual en Swift, Kotlin y JS (\b difiere con tildes).
        return title.lowercased().range(of: #"(?<![\p{L}\p{N}_])(mix|mixes|megamix|mega|best of|hits|lo mejor|top \d+|playlist|full album|[aá]lbum completo|recopilaci\p{L}*|enganchados?|cl[aá]sicos|antiguo|old school|\d+\s*(horas?|hours?)|compilation|non ?stop)(?![\p{L}\p{N}_])"#, options: .regularExpression) == nil
    }

    static func discoveryQuery(genre: String?, vibe: String?, decade: String?, country: String?) -> String? {
        let parts = [genre, vibe, decade, country].compactMap { $0?.lowercased() }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
