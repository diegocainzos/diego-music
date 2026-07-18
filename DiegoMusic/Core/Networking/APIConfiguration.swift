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
    let youtubeDataKey: String

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
