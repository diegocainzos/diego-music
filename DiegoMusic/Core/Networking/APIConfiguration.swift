import Foundation

enum APIConfigurationError: LocalizedError, Equatable {
    case missingYouTubeKey

    var errorDescription: String? {
        switch self {
        case .missingYouTubeKey:
            return "Configura YOUTUBE_DATA_KEY localmente y regenera el proyecto."
        }
    }
}

struct APIConfiguration: Sendable {
    /// Lista de claves de API disponibles para rotación en caso de agotamiento de cuota.
    let youtubeDataKeys: [String]

    /// Clave principal (la primera de la lista).
    var primaryKey: String {
        youtubeDataKeys.first ?? ""
    }

    init(youtubeDataKeys: [String]) {
        self.youtubeDataKeys = youtubeDataKeys.filter { !$0.isEmpty }
    }

    init(youtubeDataKey: String) {
        let keys = youtubeDataKey
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.youtubeDataKeys = keys
    }

    static func live(bundle: Bundle = .main) throws -> APIConfiguration {
        guard
            let rawValue = bundle.object(forInfoDictionaryKey: "YOUTUBE_DATA_KEY") as? String,
            !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !rawValue.contains("$(")
        else {
            throw APIConfigurationError.missingYouTubeKey
        }
        return APIConfiguration(youtubeDataKey: rawValue)
    }
}
