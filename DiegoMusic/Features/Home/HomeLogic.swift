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

    /// La más reciente + hasta 2 al azar (sin repetición) entre el resto de las 10 más recientes.
    static func quickPickSeeds(_ history: [MediaItem], using random: inout some RandomNumberGenerator) -> [String] {
        let recent = distinctRecent(history, limit: 10)
        guard let first = recent.first else { return [] }
        let others = recent.dropFirst().shuffled(using: &random).prefix(2).map(\.id)
        return [first.id] + others
    }

    /// Intercala los Mix (uno por semilla), sin semillas ni repetidos.
    static func mergeMixes(seeds: [String], mixes: [[MediaItem]], limit: Int = 20) -> [MediaItem] {
        var taken = Set(seeds)
        var result: [MediaItem] = []
        var index = 0
        while result.count < limit, mixes.contains(where: { index < $0.count }) {
            for mix in mixes where index < mix.count && result.count < limit {
                if taken.insert(mix[index].id).inserted { result.append(mix[index]) }
            }
            index += 1
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
