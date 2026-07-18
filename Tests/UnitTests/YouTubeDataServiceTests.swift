import XCTest
@testable import DiegoMusic

final class YouTubeDataServiceTests: XCTestCase {
    func testQuotaErrorIsMappedWithoutLeakingRequest() async throws {
        let body = #"{"error":{"code":403,"message":"quota","errors":[{"reason":"quotaExceeded","message":"quota"}]}}"#
        let transport = StubHTTPTransport(statusCode: 403, data: Data(body.utf8))
        let service = YouTubeDataService(
            configuration: APIConfiguration(youtubeDataKey: "private-test-key"),
            transport: transport
        )

        do {
            _ = try await service.search(query: "test", pageToken: nil)
            XCTFail("Se esperaba error")
        } catch {
            XCTAssertEqual(error as? YouTubeServiceError, .quotaExceeded)
            XCTAssertFalse((error as? LocalizedError)?.errorDescription?.contains("private-test-key") ?? true)
        }
    }

    func testMissingConfigurationStopsBeforeNetwork() async {
        let service = YouTubeDataService(configuration: nil, transport: StubHTTPTransport(statusCode: 200, data: Data()))
        do {
            _ = try await service.search(query: "test", pageToken: nil)
            XCTFail("Se esperaba error")
        } catch {
            XCTAssertEqual(error as? YouTubeServiceError, .missingConfiguration)
        }
    }
}

private struct StubHTTPTransport: HTTPTransport {
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
