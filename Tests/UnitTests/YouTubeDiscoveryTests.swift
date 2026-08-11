import XCTest
@testable import DiegoMusic

final class YouTubeDiscoveryTests: XCTestCase {
    func testMostPopularEndpointShape() throws {
        let request = try YouTubeEndpoint(kind: .mostPopularVideo, apiKey: "k", maxResults: 30).makeRequest()
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(components.path, "/youtube/v3/videos")
        XCTAssertEqual(values["chart"], "mostPopular")
        XCTAssertEqual(values["videoCategoryId"], "10")
        XCTAssertEqual(values["maxResults"], "30")
    }

    func testPlaylistItemsEndpointShape() throws {
        let request = try YouTubeEndpoint(
            kind: .playlistItems(playlistID: "PL123", pageToken: "PAGE"),
            apiKey: "k"
        ).makeRequest()
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(components.path, "/youtube/v3/playlistItems")
        XCTAssertEqual(values["playlistId"], "PL123")
        XCTAssertEqual(values["pageToken"], "PAGE")
    }

    func testDiscoverBuildsFeedWithArtists() async throws {
        let fixture = #"""
        {
          "nextPageToken": "NEXT",
          "items": [
            { "id": "v1", "snippet": {
                "publishedAt": "2024-01-02T03:04:05Z",
                "title": "Tema Uno",
                "channelId": "ch-1",
                "channelTitle": "Artista A",
                "thumbnails": { "high": { "url": "https://example.com/a.jpg", "width": 480, "height": 360 } }
            } },
            { "id": "v2", "snippet": {
                "publishedAt": "2024-01-02T03:04:05Z",
                "title": "Tema Dos",
                "channelId": "ch-1",
                "channelTitle": "Artista A",
                "thumbnails": { "medium": { "url": "https://example.com/b.jpg", "width": 320, "height": 180 } }
            } },
            { "id": "v3", "snippet": {
                "publishedAt": "2024-01-02T03:04:05Z",
                "title": "Tema Tres",
                "channelId": "ch-2",
                "channelTitle": "Artista B",
                "thumbnails": {}
            } }
          ]
        }
        """#
        let transport = DiscoveryStubTransport(statusCode: 200, data: Data(fixture.utf8))
        let service = YouTubeDataService(configuration: APIConfiguration(youtubeDataKey: "k"), transport: transport)

        let feed = try await service.discover()
        XCTAssertEqual(feed.novedades.count, 3)
        XCTAssertTrue(feed.artistas.count >= 2)
        XCTAssertTrue(feed.artistas.contains(where: { $0.title == "Artista A" }))
    }
}

private struct DiscoveryStubTransport: HTTPTransport {
    let statusCode: Int
    let data: Data

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}
