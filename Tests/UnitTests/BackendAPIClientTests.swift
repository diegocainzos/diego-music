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

    func testSearchCatalogSuccess() async throws {
        let json = """
        {
            "query": "rock",
            "artists": [],
            "albums": [],
            "tracks": []
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = BackendAPIClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        let searchResult = try await client.searchCatalog(query: "rock")

        XCTAssertEqual(searchResult.query, "rock")
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://api.example.test/api/v1/catalog/search?q=rock")
    }
}
