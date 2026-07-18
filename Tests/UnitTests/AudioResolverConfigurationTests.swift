import XCTest
@testable import DiegoMusic

final class AudioResolverConfigurationTests: XCTestCase {
    func testValidConfigurationNormalizesTrailingSlash() throws {
        let configuration = try AudioResolverConfiguration(
            infoDictionary: [
                "AUDIO_RESOLVER_BASE_URL": "https://audio.example.test/",
                "AUDIO_RESOLVER_API_TOKEN": "test-token-with-at-least-thirty-two-characters",
            ]
        )

        XCTAssertEqual(configuration.baseURL.absoluteString, "https://audio.example.test")
    }

    func testMissingConfigurationIsRecoverable() {
        XCTAssertThrowsError(try AudioResolverConfiguration(infoDictionary: [:])) { error in
            XCTAssertEqual(error as? AudioResolverConfigurationError, .missingConfiguration)
        }
    }

    func testConfigurationRequiresHTTPS() {
        XCTAssertThrowsError(
            try AudioResolverConfiguration(
                infoDictionary: [
                    "AUDIO_RESOLVER_BASE_URL": "http://audio.example.test",
                    "AUDIO_RESOLVER_API_TOKEN": "test-token-with-at-least-thirty-two-characters",
                ]
            )
        ) { error in
            XCTAssertEqual(error as? AudioResolverConfigurationError, .insecureBaseURL)
        }
    }

    func testConfigurationRejectsShortToken() {
        XCTAssertThrowsError(
            try AudioResolverConfiguration(
                infoDictionary: [
                    "AUDIO_RESOLVER_BASE_URL": "https://audio.example.test",
                    "AUDIO_RESOLVER_API_TOKEN": "short",
                ]
            )
        ) { error in
            XCTAssertEqual(error as? AudioResolverConfigurationError, .invalidToken)
        }
    }
}
