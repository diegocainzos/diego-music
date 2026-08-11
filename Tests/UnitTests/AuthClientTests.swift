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

final class AuthClientTests: XCTestCase {

    func testKeychainTokenManagerSaveGetDelete() throws {
        let manager = KeychainTokenManager(service: "com.diegocainzos.DiegoMusic.test", account: "testToken")
        let token = "test.jwt.token"

        try manager.saveToken(token)
        XCTAssertEqual(manager.getToken(), token)

        manager.deleteToken()
        XCTAssertNil(manager.getToken())
    }

    func testLoginSuccess() async throws {
        let json = """
        {
            "access_token": "mock.jwt.token",
            "token_type": "bearer",
            "user_id": 42,
            "email": "user@example.com"
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = AuthClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        let result = try await client.login(email: "user@example.com", password: "secretpassword")

        XCTAssertEqual(result.accessToken, "mock.jwt.token")
        XCTAssertEqual(result.userId, 42)
        XCTAssertEqual(result.email, "user@example.com")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
    }

    func testLoginInvalidCredentials() async throws {
        let json = """
        {
            "detail": "Correo electrónico o contraseña incorrectos"
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 401)
        let client = AuthClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        do {
            _ = try await client.login(email: "user@example.com", password: "wrong")
            XCTFail("Debería haber lanzado AuthError.invalidCredentials")
        } catch let error as AuthError {
            XCTAssertEqual(error, AuthError.invalidCredentials)
        }
    }

    func testRegisterSuccess() async throws {
        let json = """
        {
            "access_token": "new.jwt.token",
            "token_type": "bearer",
            "user_id": 99,
            "email": "new@example.com"
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 201)
        let client = AuthClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        let result = try await client.register(email: "new@example.com", password: "secretpassword", fullName: "Diego Music")

        XCTAssertEqual(result.accessToken, "new.jwt.token")
        XCTAssertEqual(result.userId, 99)
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testFetchMeSuccess() async throws {
        let json = """
        {
            "id": 42,
            "email": "user@example.com",
            "full_name": "Diego Music",
            "avatar_url": null,
            "is_active": true,
            "created_at": "2026-08-11T12:00:00Z",
            "last_login_at": null
        }
        """.data(using: .utf8)!

        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = AuthClient(baseURL: URL(string: "https://api.example.test")!, transport: transport)

        let user = try await client.fetchMe(token: "valid.token")

        XCTAssertEqual(user.id, 42)
        XCTAssertEqual(user.fullName, "Diego Music")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer valid.token")
    }
}
