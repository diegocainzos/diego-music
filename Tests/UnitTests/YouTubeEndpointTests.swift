import XCTest
@testable import DiegoMusic

final class YouTubeEndpointTests: XCTestCase {
    func testRequestEncodesQueryAndRequiredFilters() throws {
        let request = try YouTubeEndpoint(query: "música & calma", apiKey: "test-key", maxResults: 80).makeRequest()
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.host, "www.googleapis.com")
        XCTAssertEqual(components.path, "/youtube/v3/search")
        XCTAssertEqual(values["q"], "música & calma")
        XCTAssertEqual(values["type"], "video")
        XCTAssertEqual(values["videoCategoryId"], "10")
        XCTAssertEqual(values["videoEmbeddable"], "true")
        XCTAssertEqual(values["maxResults"], "50")
    }

    func testEmptyQueryDoesNotCreateRequest() {
        XCTAssertThrowsError(try YouTubeEndpoint(query: "   ", apiKey: "test-key").makeRequest()) { error in
            XCTAssertEqual(error as? YouTubeEndpointError, .invalidQuery)
        }
    }
}
