import Foundation

public protocol BackendAPIClientProtocol: Sendable {
    // Playlists
    func fetchMyPlaylists(token: String) async throws -> [BackendPlaylistDTO]
    func createPlaylist(token: String, name: String, description: String?, isPublic: Bool) async throws -> BackendPlaylistDTO
    func updatePlaylist(token: String, playlistID: Int, name: String?, description: String?, isPublic: Bool?) async throws -> BackendPlaylistDTO
    func deletePlaylist(token: String, playlistID: Int) async throws
    func addTrackToPlaylist(token: String, playlistID: Int, trackID: Int, order: Int?) async throws -> BackendPlaylistDTO
    func reorderPlaylistTracks(token: String, playlistID: Int, trackIDs: [Int]) async throws -> BackendPlaylistDTO
    func removeTrackFromPlaylist(token: String, playlistID: Int, trackID: Int) async throws

    // Catalog
    func searchCatalog(query: String) async throws -> CatalogSearchResponseDTO
    func fetchArtists(genre: String?, limit: Int, offset: Int) async throws -> [BackendArtistDTO]
    func fetchAlbums(artistID: Int?, genre: String?, limit: Int, offset: Int) async throws -> [BackendAlbumDTO]
    func fetchTracks(albumID: Int?, artistID: Int?, limit: Int, offset: Int) async throws -> [BackendTrackDTO]

    // User State & Sync
    func fetchUserSettings(token: String) async throws -> UserSettingsDTO
    func fetchPlayerState(token: String) async throws -> UserPlayerStateDTO
    func updatePlayerState(token: String, payload: UserPlayerStateUpdatePayload) async throws -> UserPlayerStateDTO

    // Favorites & Follows
    func fetchFavorites(token: String, entityType: String?) async throws -> [BackendFavoriteDTO]
    func addFavorite(token: String, entityType: String, entityID: Int) async throws -> BackendFavoriteDTO
    func removeFavorite(token: String, entityType: String, entityID: Int) async throws
}

public final class BackendAPIClient: BackendAPIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let transport: any HTTPTransport

    public init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    // MARK: - Playlists

    public func fetchMyPlaylists(token: String) async throws -> [BackendPlaylistDTO] {
        let url = baseURL.appendingPathComponent("api/v1/playlists/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([BackendPlaylistDTO].self, from: data)
    }

    public func createPlaylist(token: String, name: String, description: String? = nil, isPublic: Bool = false) async throws -> BackendPlaylistDTO {
        let url = baseURL.appendingPathComponent("api/v1/playlists/")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CreatePlaylistRequestPayload(name: name, description: description, isPublic: isPublic)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(BackendPlaylistDTO.self, from: data)
    }

    public func updatePlaylist(token: String, playlistID: Int, name: String? = nil, description: String? = nil, isPublic: Bool? = nil) async throws -> BackendPlaylistDTO {
        let url = baseURL.appendingPathComponent("api/v1/playlists/\(playlistID)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CreatePlaylistRequestPayload(name: name ?? "", description: description, isPublic: isPublic ?? false)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(BackendPlaylistDTO.self, from: data)
    }

    public func deletePlaylist(token: String, playlistID: Int) async throws {
        let url = baseURL.appendingPathComponent("api/v1/playlists/\(playlistID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) || response.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }

    public func addTrackToPlaylist(token: String, playlistID: Int, trackID: Int, order: Int? = 0) async throws -> BackendPlaylistDTO {
        let url = baseURL.appendingPathComponent("api/v1/playlists/\(playlistID)/tracks")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddTrackToPlaylistPayload(trackId: trackID, order: order)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(BackendPlaylistDTO.self, from: data)
    }

    public func reorderPlaylistTracks(token: String, playlistID: Int, trackIDs: [Int]) async throws -> BackendPlaylistDTO {
        let url = baseURL.appendingPathComponent("api/v1/playlists/\(playlistID)/tracks/reorder")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ReorderPlaylistTracksPayload(trackIds: trackIDs)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(BackendPlaylistDTO.self, from: data)
    }

    public func removeTrackFromPlaylist(token: String, playlistID: Int, trackID: Int) async throws {
        let url = baseURL.appendingPathComponent("api/v1/playlists/\(playlistID)/tracks/\(trackID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) || response.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Catalog

    public func searchCatalog(query: String) async throws -> CatalogSearchResponseDTO {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/catalog/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { throw URLError(.badURL) }

        let (data, response) = try await transport.data(for: URLRequest(url: url))
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(CatalogSearchResponseDTO.self, from: data)
    }

    public func fetchArtists(genre: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> [BackendArtistDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/catalog/artists"), resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "limit", value: "\(limit)"), URLQueryItem(name: "offset", value: "\(offset)")]
        if let genre { items.append(URLQueryItem(name: "genre", value: genre)) }
        components?.queryItems = items
        guard let url = components?.url else { throw URLError(.badURL) }

        let (data, response) = try await transport.data(for: URLRequest(url: url))
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([BackendArtistDTO].self, from: data)
    }

    public func fetchAlbums(artistID: Int? = nil, genre: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> [BackendAlbumDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/catalog/albums"), resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "limit", value: "\(limit)"), URLQueryItem(name: "offset", value: "\(offset)")]
        if let artistID { items.append(URLQueryItem(name: "artist_id", value: "\(artistID)")) }
        if let genre { items.append(URLQueryItem(name: "genre", value: genre)) }
        components?.queryItems = items
        guard let url = components?.url else { throw URLError(.badURL) }

        let (data, response) = try await transport.data(for: URLRequest(url: url))
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([BackendAlbumDTO].self, from: data)
    }

    public func fetchTracks(albumID: Int? = nil, artistID: Int? = nil, limit: Int = 50, offset: Int = 0) async throws -> [BackendTrackDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/catalog/tracks"), resolvingAgainstBaseURL: false)
        var items = [URLQueryItem(name: "limit", value: "\(limit)"), URLQueryItem(name: "offset", value: "\(offset)")]
        if let albumID { items.append(URLQueryItem(name: "album_id", value: "\(albumID)")) }
        if let artistID { items.append(URLQueryItem(name: "artist_id", value: "\(artistID)")) }
        components?.queryItems = items
        guard let url = components?.url else { throw URLError(.badURL) }

        let (data, response) = try await transport.data(for: URLRequest(url: url))
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([BackendTrackDTO].self, from: data)
    }

    // MARK: - User State & Sync

    public func fetchUserSettings(token: String) async throws -> UserSettingsDTO {
        let url = baseURL.appendingPathComponent("api/v1/users/me/settings")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(UserSettingsDTO.self, from: data)
    }

    public func fetchPlayerState(token: String) async throws -> UserPlayerStateDTO {
        let url = baseURL.appendingPathComponent("api/v1/users/me/player-state")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(UserPlayerStateDTO.self, from: data)
    }

    public func updatePlayerState(token: String, payload: UserPlayerStateUpdatePayload) async throws -> UserPlayerStateDTO {
        let url = baseURL.appendingPathComponent("api/v1/users/me/player-state")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(UserPlayerStateDTO.self, from: data)
    }

    // MARK: - Favorites & Follows

    public func fetchFavorites(token: String, entityType: String? = nil) async throws -> [BackendFavoriteDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/users/me/favorites"), resolvingAgainstBaseURL: false)
        if let entityType {
            components?.queryItems = [URLQueryItem(name: "entity_type", value: entityType)]
        }
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([BackendFavoriteDTO].self, from: data)
    }

    public func addFavorite(token: String, entityType: String, entityID: Int) async throws -> BackendFavoriteDTO {
        let url = baseURL.appendingPathComponent("api/v1/users/me/favorites")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddFavoritePayload(entityType: entityType, entityId: entityID)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(BackendFavoriteDTO.self, from: data)
    }

    public func removeFavorite(token: String, entityType: String, entityID: Int) async throws {
        let url = baseURL.appendingPathComponent("api/v1/users/me/favorites/\(entityType)/\(entityID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await transport.data(for: request)
        guard (200...299).contains(response.statusCode) || response.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }
}
