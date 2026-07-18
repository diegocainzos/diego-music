import Foundation

enum AudioResolverConfigurationError: LocalizedError, Equatable, Sendable {
    case missingConfiguration
    case invalidBaseURL
    case insecureBaseURL
    case invalidToken

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Configura el servicio privado de audio antes de reproducir."
        case .invalidBaseURL:
            return "La dirección del servicio de audio no es válida."
        case .insecureBaseURL:
            return "El servicio de audio debe usar HTTPS."
        case .invalidToken:
            return "La credencial del servicio de audio no es válida."
        }
    }
}

struct AudioResolverConfiguration: Equatable, Sendable {
    let baseURL: URL
    let apiToken: String

    init(baseURL: URL, apiToken: String) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil
        else {
            throw AudioResolverConfigurationError.invalidBaseURL
        }
        guard components.scheme?.lowercased() == "https" else {
            throw AudioResolverConfigurationError.insecureBaseURL
        }

        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~-")
        guard token.count >= 32, token.unicodeScalars.allSatisfy(allowed.contains) else {
            throw AudioResolverConfigurationError.invalidToken
        }

        let normalized = baseURL.absoluteString.hasSuffix("/")
            ? URL(string: String(baseURL.absoluteString.dropLast())) ?? baseURL
            : baseURL
        self.baseURL = normalized
        self.apiToken = token
    }

    init(infoDictionary: [String: Any]) throws {
        let rawURL = (infoDictionary["AUDIO_RESOLVER_BASE_URL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let token = (infoDictionary["AUDIO_RESOLVER_API_TOKEN"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawURL.isEmpty, !token.isEmpty, !rawURL.contains("$("), !token.contains("$(") else {
            throw AudioResolverConfigurationError.missingConfiguration
        }
        guard let baseURL = URL(string: rawURL) else {
            throw AudioResolverConfigurationError.invalidBaseURL
        }
        try self.init(baseURL: baseURL, apiToken: token)
    }

    static func live(bundle: Bundle = .main) throws -> AudioResolverConfiguration {
        try AudioResolverConfiguration(infoDictionary: bundle.infoDictionary ?? [:])
    }
}
