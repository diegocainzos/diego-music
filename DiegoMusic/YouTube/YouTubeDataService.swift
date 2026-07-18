import Foundation

enum YouTubeServiceError: LocalizedError, Equatable {
    case missingConfiguration
    case invalidRequest
    case unauthorized
    case quotaExceeded
    case server(status: Int)
    case invalidResponse
    case network

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Falta configurar YOUTUBE_DATA_KEY localmente."
        case .invalidRequest:
            return "La búsqueda no es válida."
        case .unauthorized:
            return "YouTube rechazó la configuración de acceso. Revisa las restricciones de la clave."
        case .quotaExceeded:
            return "La cuota diaria de YouTube Data API se ha agotado."
        case .server:
            return "YouTube no está disponible temporalmente."
        case .invalidResponse:
            return "YouTube devolvió una respuesta que no se pudo interpretar."
        case .network:
            return "No se pudo conectar con YouTube. Revisa la conexión."
        }
    }
}

protocol YouTubeDataServicing: Sendable {
    func search(query: String, pageToken: String?) async throws -> SearchPage
}

struct YouTubeDataService: YouTubeDataServicing {
    private let configuration: APIConfiguration?
    private let transport: any HTTPTransport
    private let mapper: YouTubeMapper

    init(
        configuration: APIConfiguration?,
        transport: any HTTPTransport = URLSessionTransport(),
        mapper: YouTubeMapper = YouTubeMapper()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.mapper = mapper
    }

    func search(query: String, pageToken: String? = nil) async throws -> SearchPage {
        guard let configuration else { throw YouTubeServiceError.missingConfiguration }
        let request: URLRequest
        do {
            request = try YouTubeEndpoint(
                query: query,
                apiKey: configuration.youtubeDataKey,
                pageToken: pageToken
            ).makeRequest()
        } catch {
            throw YouTubeServiceError.invalidRequest
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            throw YouTubeServiceError.network
        }

        switch response.statusCode {
        case 200..<300:
            guard let decoded = try? JSONDecoder.youtube.decode(YouTubeSearchResponseDTO.self, from: data) else {
                throw YouTubeServiceError.invalidResponse
            }
            return mapper.map(decoded)
        case 400:
            throw YouTubeServiceError.invalidRequest
        case 401:
            throw YouTubeServiceError.unauthorized
        case 403:
            if isQuotaError(data) { throw YouTubeServiceError.quotaExceeded }
            throw YouTubeServiceError.unauthorized
        case 500...599:
            throw YouTubeServiceError.server(status: response.statusCode)
        default:
            throw YouTubeServiceError.server(status: response.statusCode)
        }
    }

    private func isQuotaError(_ data: Data) -> Bool {
        guard let envelope = try? JSONDecoder().decode(YouTubeAPIErrorEnvelopeDTO.self, from: data) else {
            return false
        }
        let reasons = envelope.error.errors?.compactMap(\.reason) ?? []
        return reasons.contains { reason in
            reason == "quotaExceeded" || reason == "dailyLimitExceeded" || reason == "rateLimitExceeded"
        }
    }
}
