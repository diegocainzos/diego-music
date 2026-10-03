import Foundation

/// Cliente REST del backend FastAPI (`/api/v1/*`) para playlists, favoritos e historial.
///
/// Todas las operaciones pasan por `send`, que construye la petición con la
/// cabecera `Authorization: Bearer`, valida el estado `2xx` y decodifica la respuesta.
public final class BackendAPIClient: @unchecked Sendable {
    private let baseURL: URL
    private let transport: any HTTPTransport

    public init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    // MARK: - Playlists

    public func fetchMyPlaylists(token: String) async throws -> [BackendPlaylistDTO] {
        try await send("GET", "api/v1/playlists/me", token: token)
    }

    public func fetchPlaylist(token: String, playlistID: Int) async throws -> BackendPlaylistDTO {
        try await send("GET", "api/v1/playlists/\(playlistID)", token: token)
    }

    public func createPlaylist(token: String, name: String, description: String? = nil, isPublic: Bool = false) async throws -> BackendPlaylistDTO {
        try await send(
            "POST",
            "api/v1/playlists/",
            token: token,
            body: CreatePlaylistRequestPayload(name: name, description: description, isPublic: isPublic)
        )
    }

    public func deletePlaylist(token: String, playlistID: Int) async throws {
        try await sendDiscardingResponse("DELETE", "api/v1/playlists/\(playlistID)", token: token)
    }

    public func addTrackToPlaylist(
        token: String,
        playlistID: Int,
        youtubeVideoId: String,
        title: String? = nil,
        channelTitle: String? = nil,
        thumbnailUrl: String? = nil,
        durationSeconds: Int? = nil,
        order: Int? = 0
    ) async throws -> BackendPlaylistDTO {
        try await send(
            "POST",
            "api/v1/playlists/\(playlistID)/tracks",
            token: token,
            body: AddTrackToPlaylistPayload(
                youtubeVideoId: youtubeVideoId,
                title: title,
                channelTitle: channelTitle,
                thumbnailUrl: thumbnailUrl,
                durationSeconds: durationSeconds,
                order: order
            )
        )
    }

    public func removeTrackFromPlaylist(token: String, playlistID: Int, trackIdentifier: String) async throws {
        try await sendDiscardingResponse("DELETE", "api/v1/playlists/\(playlistID)/tracks/\(trackIdentifier)", token: token)
    }

    // MARK: - Favorites

    public func fetchFavorites(token: String, entityType: String? = nil) async throws -> [BackendFavoriteDTO] {
        try await send(
            "GET",
            "api/v1/users/me/favorites",
            token: token,
            query: entityType.map { [URLQueryItem(name: "entity_type", value: $0)] }
        )
    }

    public func addFavorite(
        token: String,
        entityType: String,
        youtubeVideoId: String,
        title: String? = nil,
        channelTitle: String? = nil,
        thumbnailUrl: String? = nil,
        durationSeconds: Int? = nil
    ) async throws -> BackendFavoriteDTO {
        try await send(
            "POST",
            "api/v1/users/me/favorites",
            token: token,
            body: AddFavoritePayload(
                entityType: entityType,
                youtubeVideoId: youtubeVideoId,
                title: title,
                channelTitle: channelTitle,
                thumbnailUrl: thumbnailUrl,
                durationSeconds: durationSeconds
            )
        )
    }

    public func removeFavorite(token: String, entityType: String, entityIdentifier: String) async throws {
        try await sendDiscardingResponse("DELETE", "api/v1/users/me/favorites/\(entityType)/\(entityIdentifier)", token: token)
    }

    // MARK: - History

    public func recordPlayHistory(
        token: String,
        youtubeVideoId: String,
        title: String? = nil,
        channelTitle: String? = nil,
        thumbnailUrl: String? = nil,
        durationSeconds: Int? = nil,
        playedSeconds: Int = 0
    ) async throws {
        try await sendDiscardingResponse(
            "POST",
            "api/v1/users/me/history",
            token: token,
            body: RecordPlayHistoryPayload(
                youtubeVideoId: youtubeVideoId,
                title: title,
                channelTitle: channelTitle,
                thumbnailUrl: thumbnailUrl,
                durationSeconds: durationSeconds,
                playedSeconds: Double(playedSeconds),
                completed: true
            )
        )
    }

    public func fetchPlayHistory(token: String, limit: Int = 20, offset: Int = 0) async throws -> [BackendPlayHistoryDTO] {
        try await send(
            "GET",
            "api/v1/users/me/history",
            token: token,
            query: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    // MARK: - Transporte

    /// Envía la petición y decodifica el cuerpo de la respuesta como `Response`.
    private func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        token: String,
        query: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> Response {
        let data = try await perform(method, path, token: token, query: query, body: body)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Envía la petición y descarta el cuerpo de la respuesta (`DELETE`, historial).
    private func sendDiscardingResponse(
        _ method: String,
        _ path: String,
        token: String,
        query: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws {
        _ = try await perform(method, path, token: token, query: query, body: body)
    }

    /// Construye la petición, la entrega al transporte y exige un estado `2xx`.
    private func perform(
        _ method: String,
        _ path: String,
        token: String,
        query: [URLQueryItem]?,
        body: (any Encodable)?
    ) async throws -> Data {
        var url = baseURL.appendingPathComponent(path)
        if let query, !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = query
            guard let queryURL = components?.url else { throw URLError(.badURL) }
            url = queryURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
