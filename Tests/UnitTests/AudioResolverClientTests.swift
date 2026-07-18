import XCTest
@testable import DiegoMusic

final class AudioResolverClientTests: XCTestCase {
    private let token = "test-token-with-at-least-thirty-two-characters"

    func testResolveBuildsAuthenticatedRequestAndDecodesDescriptor() async throws {
        let recorder = RequestRecorder()
        let body = #"{"streamURL":"https://audio.example.test/v1/audio/stream/opaque","expiresAt":"2099-01-01T00:00:00Z","contentType":"audio/mp4"}"#
        let client = try makeClient(statusCode: 200, body: body, recorder: recorder)

        let descriptor = try await client.resolve(videoID: "M7lc1UVf-VE")
        let recordedRequest = await recorder.lastRequest()
        let request = try XCTUnwrap(recordedRequest)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://audio.example.test/v1/audio/resolve")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), #"{"videoId":"M7lc1UVf-VE"}"#)
        XCTAssertEqual(descriptor.streamURL.absoluteString, "https://audio.example.test/v1/audio/stream/opaque")
        XCTAssertEqual(descriptor.contentType, "audio/mp4")
    }

    func testDescriptorCacheAvoidsSecondRequest() async throws {
        let recorder = RequestRecorder()
        let body = #"{"streamURL":"https://audio.example.test/v1/audio/stream/opaque","expiresAt":"2099-01-01T00:00:00Z","contentType":"audio/mp4","cacheStatus":"miss"}"#
        let client = try makeClient(statusCode: 200, body: body, recorder: recorder)

        _ = try await client.resolve(videoID: "M7lc1UVf-VE")
        _ = try await client.resolve(videoID: "M7lc1UVf-VE")

        let requestCount = await recorder.requestCount()
        let cacheCount = await client.cacheEntryCount
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(cacheCount, 1)
    }

    func testNearExpiryDescriptorIsNotCached() async throws {
        let recorder = RequestRecorder()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiration = ISO8601DateFormatter().string(from: now.addingTimeInterval(60))
        let body = #"{"streamURL":"https://audio.example.test/v1/audio/stream/short","expiresAt":"\#(expiration)","contentType":"audio/mp4"}"#
        let client = try makeClient(
            statusCode: 200,
            body: body,
            recorder: recorder,
            expirationSafetyMargin: 90,
            clock: { now }
        )

        _ = try await client.resolve(videoID: "M7lc1UVf-VE")
        _ = try await client.resolve(videoID: "M7lc1UVf-VE")

        let requestCount = await recorder.requestCount()
        XCTAssertEqual(requestCount, 2)
    }

    func testInvalidationForcesNewRequest() async throws {
        let recorder = RequestRecorder()
        let body = #"{"streamURL":"https://audio.example.test/v1/audio/stream/opaque","expiresAt":"2099-01-01T00:00:00Z","contentType":"audio/mp4"}"#
        let client = try makeClient(statusCode: 200, body: body, recorder: recorder)

        _ = try await client.resolve(videoID: "M7lc1UVf-VE")
        await client.invalidate(videoID: "M7lc1UVf-VE")
        _ = try await client.resolve(videoID: "M7lc1UVf-VE")

        let requestCount = await recorder.requestCount()
        XCTAssertEqual(requestCount, 2)
    }

    func testConcurrentResolvesShareRequest() async throws {
        let recorder = RequestRecorder()
        let body = #"{"streamURL":"https://audio.example.test/v1/audio/stream/opaque","expiresAt":"2099-01-01T00:00:00Z","contentType":"audio/mp4"}"#
        let client = try makeClient(
            statusCode: 200,
            body: body,
            recorder: recorder,
            delayNanoseconds: 30_000_000
        )

        async let first = client.resolve(videoID: "M7lc1UVf-VE")
        async let second = client.resolve(videoID: "M7lc1UVf-VE")
        async let third = client.resolve(videoID: "M7lc1UVf-VE")
        _ = try await [first, second, third]

        let requestCount = await recorder.requestCount()
        XCTAssertEqual(requestCount, 1)
    }

    func testInvalidIDStopsBeforeNetwork() async throws {
        let recorder = RequestRecorder()
        let client = try makeClient(statusCode: 200, body: "{}", recorder: recorder)

        do {
            _ = try await client.resolve(videoID: "not-a-video-url")
            XCTFail("Se esperaba un error")
        } catch {
            XCTAssertEqual(error as? AudioResolverServiceError, .invalidVideoID)
        }
        let recordedRequest = await recorder.lastRequest()
        XCTAssertNil(recordedRequest)
    }

    func testUnauthorizedErrorDoesNotContainToken() async throws {
        let recorder = RequestRecorder()
        let client = try makeClient(statusCode: 401, body: #"{"detail":"no"}"#, recorder: recorder)

        do {
            _ = try await client.resolve(videoID: "M7lc1UVf-VE")
            XCTFail("Se esperaba un error")
        } catch {
            XCTAssertEqual(error as? AudioResolverServiceError, .unauthorized)
            XCTAssertFalse(error.localizedDescription.contains(token))
        }
    }

    func testServerURLIsNotSurfacedInRejectedError() async throws {
        let recorder = RequestRecorder()
        let client = try makeClient(
            statusCode: 422,
            body: #"{"detail":"falló https://rr1.googlevideo.com/private"}"#,
            recorder: recorder
        )

        do {
            _ = try await client.resolve(videoID: "M7lc1UVf-VE")
            XCTFail("Se esperaba un error")
        } catch {
            XCTAssertEqual(
                (error as? AudioResolverServiceError)?.errorDescription,
                "Este contenido no ofrece una pista de audio compatible."
            )
            XCTAssertFalse(error.localizedDescription.contains("googlevideo"))
        }
    }

    func testInvalidSuccessPayloadIsRejected() async throws {
        let recorder = RequestRecorder()
        let body = #"{"streamURL":"http://audio.example.test/stream","expiresAt":"2099-01-01T00:00:00Z","contentType":"audio/mp4"}"#
        let client = try makeClient(statusCode: 200, body: body, recorder: recorder)

        do {
            _ = try await client.resolve(videoID: "M7lc1UVf-VE")
            XCTFail("Se esperaba un error")
        } catch {
            XCTAssertEqual(error as? AudioResolverServiceError, .invalidResponse)
        }
    }

    private func makeClient(
        statusCode: Int,
        body: String,
        recorder: RequestRecorder,
        expirationSafetyMargin: TimeInterval = 90,
        clock: @escaping @Sendable () -> Date = { Date() },
        delayNanoseconds: UInt64 = 0
    ) throws -> AudioResolverClient {
        let configuration = try AudioResolverConfiguration(
            baseURL: XCTUnwrap(URL(string: "https://audio.example.test")),
            apiToken: token
        )
        return AudioResolverClient(
            configuration: configuration,
            transport: RecordingHTTPTransport(
                statusCode: statusCode,
                data: Data(body.utf8),
                recorder: recorder,
                delayNanoseconds: delayNanoseconds
            ),
            expirationSafetyMargin: expirationSafetyMargin,
            clock: clock
        )
    }
}

private actor RequestRecorder {
    private var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        requests.append(request)
    }

    func lastRequest() -> URLRequest? {
        requests.last
    }

    func requestCount() -> Int {
        requests.count
    }
}

private struct RecordingHTTPTransport: HTTPTransport {
    let statusCode: Int
    let data: Data
    let recorder: RequestRecorder
    let delayNanoseconds: UInt64

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        await recorder.record(request)
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}
