import Foundation

enum YouTubeServiceError: LocalizedError, Equatable {
    case missingConfiguration
    case invalidRequest
    case unauthorized
    case quotaExceeded
    case server(status: Int)
    case invalidResponse
    case network
    case unavailable

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
        case .unavailable:
            return "Esta función de descubrimiento no está disponible."
        }
    }
}

protocol YouTubeDataServicing: Sendable {
    func search(query: String, pageToken: String?) async throws -> SearchPage

    func discover() async throws -> DiscoveryFeed
    func artist(byChannelID: String) async throws -> ArtistDetail
    func album(byPlaylistID: String) async throws -> Album
}

/// Implementaciones por defecto para no forzar cambios en conformantes actuales.
extension YouTubeDataServicing {
    func discover() async throws -> DiscoveryFeed { throw YouTubeServiceError.unavailable }
    func artist(byChannelID: String) async throws -> ArtistDetail { throw YouTubeServiceError.unavailable }
    func album(byPlaylistID: String) async throws -> Album { throw YouTubeServiceError.unavailable }
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
        let apiKey = try key()
        let request = try endpointRequest {
            YouTubeEndpoint(query: query, apiKey: apiKey, pageToken: pageToken)
        }
        let data = try await run(request, response: YouTubeSearchResponseDTO.self)
        return mapper.map(data)
    }

    func discover() async throws -> DiscoveryFeed {
        let apiKey = try key()
        let request = try endpointRequest {
            YouTubeEndpoint(kind: .mostPopularVideo, apiKey: apiKey)
        }
        let data = try await run(request, response: YouTubeVideoListEnvelopeDTO.self)
        var seenChannelIDs: Set<String> = []
        let artistas: [ArtistReference] = data.items.compactMap { dto in
            guard let channelID = dto.snippet.channelId, !channelID.isEmpty else { return nil }
            guard !seenChannelIDs.contains(channelID) else { return nil }
            seenChannelIDs.insert(channelID)
            let thumbnail = dto.snippet.thumbnails["high"]
                ?? dto.snippet.thumbnails["medium"]
                ?? dto.snippet.thumbnails["default"]
            return ArtistReference(
                id: channelID,
                title: dto.snippet.channelTitle.decodingHTML,
                thumbnailURL: thumbnail?.url
            )
        }
        return DiscoveryFeed(
            novedades: data.items.map(mapper.map),
            artistas: artistas
        )
    }

    func artist(byChannelID channelID: String) async throws -> ArtistDetail {
        guard !channelID.isEmpty else { throw YouTubeServiceError.invalidRequest }
        let apiKey = try key()

        let profileRequest = try endpointRequest {
            YouTubeEndpoint(kind: .channels(ids: [channelID]), apiKey: apiKey)
        }
        let profileData = try await run(profileRequest, response: YouTubeChannelListResponseDTO.self)
        guard let artist = profileData.items.first.map(mapper.map) else {
            throw YouTubeServiceError.invalidResponse
        }

        // Top tracks y relacionados son best-effort públicos de vídeo.
        let topRequest = try endpointRequest {
            YouTubeEndpoint(query: artist.title, apiKey: apiKey, maxResults: 20)
        }
        let relatedRequest = try endpointRequest {
            YouTubeEndpoint(kind: .mostPopularVideo, apiKey: apiKey, maxResults: 12)
        }
        let (topData, relatedData) = try await (
            run(topRequest, response: YouTubeSearchResponseDTO.self),
            run(relatedRequest, response: YouTubeVideoListEnvelopeDTO.self)
        )
        return ArtistDetail(
            artist: artist,
            topTracks: topData.items.compactMap(mapper.map),
            related: relatedData.items.map(mapper.map)
        )
    }

    func album(byPlaylistID playlistID: String) async throws -> Album {
        guard !playlistID.isEmpty else { throw YouTubeServiceError.invalidRequest }
        let apiKey = try key()

        let request = try endpointRequest {
            YouTubeEndpoint(kind: .playlistItems(playlistID: playlistID, pageToken: nil), apiKey: apiKey)
        }
        let data = try await run(request, response: YouTubePlaylistItemsResponseDTO.self)
        let tracks = data.items.compactMap(mapper.map)
        let first = data.items.first?.snippet
        return Album(
            id: playlistID,
            title: first?.title ?? "Álbum / Lista",
            channelTitle: first?.channelTitle,
            thumbnailURL: first?.thumbnails["high"]?.url ?? first?.thumbnails["medium"]?.url,
            tracks: tracks
        )
    }

    // MARK: - Helpers

    private func key() throws -> String {
        guard let configuration else { throw YouTubeServiceError.missingConfiguration }
        return configuration.youtubeDataKey
    }

    private func endpointRequest(_ build: () throws -> YouTubeEndpoint) throws -> URLRequest {
        do {
            return try build().makeRequest()
        } catch {
            throw YouTubeServiceError.invalidRequest
        }
    }

    private func run<Response: Decodable>(_ request: URLRequest, response _: Response.Type) async throws -> Response {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            throw YouTubeServiceError.network
        }

        switch response.statusCode {
        case 200..<300:
            guard let decoded = try? JSONDecoder.youtube.decode(Response.self, from: data) else {
                throw YouTubeServiceError.invalidResponse
            }
            return decoded
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

private extension String {
    var decodingHTML: String {
        guard let data = data(using: .utf8) else { return self }
        return (try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ).string) ?? self
    }
}
