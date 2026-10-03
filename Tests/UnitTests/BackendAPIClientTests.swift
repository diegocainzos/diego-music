import XCTest
@testable import DiegoMusic

private final class MockTransport: HTTPTransport, @unchecked Sendable {
    var responseData: Data
    var statusCode: Int
    var lastRequest: URLRequest?

    init(responseData: Data = Data(), statusCode: Int = 200) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.lastRequest = request
        let url = request.url ?? URL(string: "https://example.test")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (responseData, response)
    }
}

final class BackendAPIClientTests: XCTestCase {

    func testFetchMyPlaylistsSuccess() async throws {
        let json = """
        [
            {
                "id": 1,
                "name": "Mis Favoritas",
                "description": "Lista de prueba",
                "cover_url": null,
                "is_public": false,
                "user_id": 42,
                "created_at": "2026-08-11T12:00:00Z",
                "updated_at": "2026-08-11T12:00:00Z",
                "tracks": []
            }
        ]
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = BackendAPIClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        let playlists = try await client.fetchMyPlaylists(token: "valid.token")

        XCTAssertEqual(playlists.count, 1)
        XCTAssertEqual(playlists.first?.name, "Mis Favoritas")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer valid.token")
    }

    func testCreatePlaylistSuccess() async throws {
        let json = """
        {
            "id": 2,
            "name": "Noche Chill",
            "description": null,
            "cover_url": null,
            "is_public": true,
            "user_id": 42,
            "created_at": "2026-08-11T12:00:00Z",
            "updated_at": "2026-08-11T12:00:00Z",
            "tracks": []
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 201)
        let client = BackendAPIClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        let created = try await client.createPlaylist(token: "valid.token", name: "Noche Chill", isPublic: true)

        XCTAssertEqual(created.id, 2)
        XCTAssertEqual(created.name, "Noche Chill")
        XCTAssertTrue(created.isPublic)
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
    }

    func testAddTrackToPlaylistWithYouTubeVideoId() async throws {
        let json = """
        {
            "id": 2,
            "name": "Noche Chill",
            "is_public": false,
            "user_id": 42,
            "created_at": "2026-08-11T12:00:00Z",
            "updated_at": "2026-08-11T12:00:00Z",
            "tracks": []
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = BackendAPIClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        let result = try await client.addTrackToPlaylist(
            token: "valid.token",
            playlistID: 2,
            youtubeVideoId: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            channelTitle: "Rick Astley",
            thumbnailUrl: nil,
            durationSeconds: 213,
            order: 0
        )

        XCTAssertEqual(result.id, 2)
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.url?.path, "/api/v1/playlists/2/tracks")
    }

    func testAddFavoriteWithYouTubeVideoId() async throws {
        let json = """
        {
            "id": 10,
            "user_id": 42,
            "entity_type": "track",
            "entity_id": 101,
            "created_at": "2026-08-11T12:00:00Z"
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 201)
        let client = BackendAPIClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        let fav = try await client.addFavorite(
            token: "valid.token",
            entityType: "track",
            youtubeVideoId: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            channelTitle: "Rick Astley"
        )

        XCTAssertEqual(fav.id, 10)
        XCTAssertEqual(fav.entityType, "track")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.url?.path, "/api/v1/users/me/favorites")
    }

    func testRecordPlayHistoryWithYouTubeVideoId() async throws {
        let transport = MockTransport(responseData: Data(), statusCode: 201)
        let client = BackendAPIClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        try await client.recordPlayHistory(
            token: "valid.token",
            youtubeVideoId: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            channelTitle: "Rick Astley",
            thumbnailUrl: nil,
            durationSeconds: 213,
            playedSeconds: 120
        )

        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.url?.path, "/api/v1/users/me/history")
    }

    func testFetchPlaylistUsesPlaylistIdPath() async throws {
        let json = """
        {
            "id": 7,
            "name": "Ruta",
            "is_public": false,
            "user_id": 42,
            "tracks": []
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = makeClient(transport)

        let playlist = try await client.fetchPlaylist(token: "valid.token", playlistID: 7)

        XCTAssertEqual(playlist.id, 7)
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(transport.lastRequest?.url?.path, "/api/v1/playlists/7")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer valid.token")
    }

    func testCreatePlaylistKeepsTrailingSlashAndSendsJSONBody() async throws {
        let json = """
        {"id": 3, "name": "Gym", "is_public": false, "user_id": 42, "tracks": []}
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 201)
        let client = makeClient(transport)

        _ = try await client.createPlaylist(token: "valid.token", name: "Gym", description: "Entreno", isPublic: false)

        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://api.example.test/api/v1/playlists/")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer valid.token")
        let body = try jsonBody(of: transport)
        XCTAssertEqual(body["name"] as? String, "Gym")
        XCTAssertEqual(body["description"] as? String, "Entreno")
        XCTAssertEqual(body["is_public"] as? Bool, false)
    }

    func testAddTrackToPlaylistSendsYouTubeIdentityOnly() async throws {
        let json = """
        {"id": 2, "name": "Noche Chill", "is_public": false, "user_id": 42, "tracks": []}
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = makeClient(transport)

        _ = try await client.addTrackToPlaylist(
            token: "valid.token",
            playlistID: 2,
            youtubeVideoId: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            order: nil
        )

        let body = try jsonBody(of: transport)
        XCTAssertEqual(body["youtube_video_id"] as? String, "dQw4w9WgXcQ")
        XCTAssertEqual(body["title"] as? String, "Never Gonna Give You Up")
        XCTAssertNil(body["track_id"])
        XCTAssertNil(body["order"])
    }

    func testDeletePlaylistAcceptsNoContent() async throws {
        let transport = MockTransport(statusCode: 204)
        let client = makeClient(transport)

        try await client.deletePlaylist(token: "valid.token", playlistID: 5)

        XCTAssertEqual(transport.lastRequest?.httpMethod, "DELETE")
        XCTAssertEqual(transport.lastRequest?.url?.path, "/api/v1/playlists/5")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer valid.token")
        XCTAssertNil(transport.lastRequest?.httpBody)
        XCTAssertNil(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"))
    }

    func testRemoveTrackFromPlaylistUsesTrackIdentifierPath() async throws {
        let transport = MockTransport(statusCode: 204)
        let client = makeClient(transport)

        try await client.removeTrackFromPlaylist(token: "valid.token", playlistID: 2, trackIdentifier: "dQw4w9WgXcQ")

        XCTAssertEqual(transport.lastRequest?.httpMethod, "DELETE")
        XCTAssertEqual(transport.lastRequest?.url?.path, "/api/v1/playlists/2/tracks/dQw4w9WgXcQ")
    }

    func testFetchFavoritesEncodesEntityTypeQuery() async throws {
        let transport = MockTransport(responseData: "[]".data(using: .utf8)!, statusCode: 200)
        let client = makeClient(transport)

        let favorites = try await client.fetchFavorites(token: "valid.token", entityType: "track")

        XCTAssertTrue(favorites.isEmpty)
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://api.example.test/api/v1/users/me/favorites?entity_type=track"
        )
    }

    func testFetchFavoritesWithoutEntityTypeHasNoQuery() async throws {
        let transport = MockTransport(responseData: "[]".data(using: .utf8)!, statusCode: 200)
        let client = makeClient(transport)

        _ = try await client.fetchFavorites(token: "valid.token")

        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://api.example.test/api/v1/users/me/favorites")
    }

    func testRemoveFavoriteUsesEntityPath() async throws {
        let transport = MockTransport(statusCode: 204)
        let client = makeClient(transport)

        try await client.removeFavorite(token: "valid.token", entityType: "track", entityIdentifier: "dQw4w9WgXcQ")

        XCTAssertEqual(transport.lastRequest?.httpMethod, "DELETE")
        XCTAssertEqual(transport.lastRequest?.url?.path, "/api/v1/users/me/favorites/track/dQw4w9WgXcQ")
    }

    func testRecordPlayHistorySendsPlayedSecondsAndCompletedFlag() async throws {
        let transport = MockTransport(statusCode: 201)
        let client = makeClient(transport)

        try await client.recordPlayHistory(token: "valid.token", youtubeVideoId: "dQw4w9WgXcQ", playedSeconds: 120)

        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try jsonBody(of: transport)
        XCTAssertEqual(body["youtube_video_id"] as? String, "dQw4w9WgXcQ")
        XCTAssertEqual(body["played_seconds"] as? Double, 120)
        XCTAssertEqual(body["completed"] as? Bool, true)
        XCTAssertNil(body["track_id"])
    }

    func testFetchPlayHistoryEncodesPaginationQueryAndDecodes() async throws {
        let json = """
        [
            {
                "id": 1,
                "user_id": 42,
                "track_id": 7,
                "played_seconds": 12.5,
                "completed": true,
                "skipped": false,
                "context": null,
                "device": null,
                "played_at": "2026-08-11T12:00:00Z",
                "track": null
            }
        ]
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = makeClient(transport)

        let history = try await client.fetchPlayHistory(token: "valid.token", limit: 50, offset: 10)

        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.trackId, 7)
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://api.example.test/api/v1/users/me/history?limit=50&offset=10"
        )
    }

    // MARK: - Errores de estado y decodificación

    func testNonSuccessStatusThrowsBadServerResponseWhenDecoding() async throws {
        let transport = MockTransport(responseData: "[]".data(using: .utf8)!, statusCode: 500)
        let client = makeClient(transport)

        do {
            _ = try await client.fetchMyPlaylists(token: "valid.token")
            XCTFail("Debería haber lanzado URLError.badServerResponse")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        }
    }

    func testNonSuccessStatusThrowsBadServerResponseWhenDiscardingResponse() async throws {
        let transport = MockTransport(statusCode: 404)
        let client = makeClient(transport)

        do {
            try await client.deletePlaylist(token: "valid.token", playlistID: 99)
            XCTFail("Debería haber lanzado URLError.badServerResponse")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        }
    }

    func testUnauthorizedStatusThrowsBadServerResponse() async throws {
        let transport = MockTransport(responseData: "{\"detail\": \"No autorizado\"}".data(using: .utf8)!, statusCode: 401)
        let client = makeClient(transport)

        do {
            _ = try await client.createPlaylist(token: "expired.token", name: "Gym")
            XCTFail("Debería haber lanzado URLError.badServerResponse")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        }
    }

    // MARK: - Helpers

    private func makeClient(_ transport: MockTransport) -> BackendAPIClient {
        BackendAPIClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)
    }

    private func jsonBody(of transport: MockTransport) throws -> [String: Any] {
        let data = try XCTUnwrap(transport.lastRequest?.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
