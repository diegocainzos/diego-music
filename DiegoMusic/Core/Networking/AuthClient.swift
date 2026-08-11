import Foundation

/// Errores tipados y sanitizados de autenticación.
public enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case emailAlreadyRegistered
    case unauthenticated
    case serverError(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Correo electrónico o contraseña incorrectos."
        case .emailAlreadyRegistered:
            return "El correo electrónico ya está registrado."
        case .unauthenticated:
            return "Sesión no válida o expirada."
        case .serverError(let message):
            return message
        case .invalidResponse:
            return "Respuesta del servidor no válida."
        }
    }
}

/// Protocolo para cliente de autenticación backend.
public protocol AuthClientProtocol: Sendable {
    func login(email: String, password: String) async throws -> AuthTokenResponse
    func register(email: String, password: String, fullName: String?) async throws -> AuthTokenResponse
    func fetchMe(token: String) async throws -> UserDTO
    func updateMe(token: String, fullName: String?, avatarURL: String?) async throws -> UserDTO
}

/// Cliente de red para autenticación contra el backend FastAPI (`/api/v1/auth/*`).
public final class AuthClient: AuthClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let transport: any HTTPTransport

    public init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func login(email: String, password: String) async throws -> AuthTokenResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/auth/login"), resolvingAgainstBaseURL: false)
        guard let url = components?.url else {
            throw AuthError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let formString = "username=\(percentEncode(email))&password=\(percentEncode(password))"
        request.httpBody = formString.data(using: .utf8)

        let (data, response) = try await transport.data(for: request)

        if response.statusCode == 401 {
            throw AuthError.invalidCredentials
        }
        guard (200...299).contains(response.statusCode) else {
            let serverMsg = parseErrorMessage(from: data) ?? "Error en el servidor (\(response.statusCode))."
            throw AuthError.serverError(serverMsg)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AuthTokenResponse.self, from: data)
        } catch {
            throw AuthError.invalidResponse
        }
    }

    public func register(email: String, password: String, fullName: String?) async throws -> AuthTokenResponse {
        let url = baseURL.appendingPathComponent("api/v1/auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = RegisterRequestPayload(email: email, password: password, fullName: fullName)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await transport.data(for: request)

        if response.statusCode == 400 {
            let msg = parseErrorMessage(from: data)
            if msg?.contains("registrado") == true {
                throw AuthError.emailAlreadyRegistered
            }
            throw AuthError.serverError(msg ?? "Error al registrar usuario.")
        }
        guard (200...299).contains(response.statusCode) else {
            let serverMsg = parseErrorMessage(from: data) ?? "Error en el servidor (\(response.statusCode))."
            throw AuthError.serverError(serverMsg)
        }

        do {
            return try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        } catch {
            throw AuthError.invalidResponse
        }
    }

    public func fetchMe(token: String) async throws -> UserDTO {
        let url = baseURL.appendingPathComponent("api/v1/auth/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await transport.data(for: request)

        if response.statusCode == 401 {
            throw AuthError.unauthenticated
        }
        guard (200...299).contains(response.statusCode) else {
            throw AuthError.serverError("No se pudo obtener el perfil de usuario.")
        }

        do {
            return try JSONDecoder().decode(UserDTO.self, from: data)
        } catch {
            throw AuthError.invalidResponse
        }
    }

    public func updateMe(token: String, fullName: String?, avatarURL: String?) async throws -> UserDTO {
        let url = baseURL.appendingPathComponent("api/v1/auth/me")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = UserUpdatePayload(fullName: fullName, avatarURL: avatarURL)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await transport.data(for: request)

        if response.statusCode == 401 {
            throw AuthError.unauthenticated
        }
        guard (200...299).contains(response.statusCode) else {
            throw AuthError.serverError("No se pudo actualizar el perfil.")
        }

        do {
            return try JSONDecoder().decode(UserDTO.self, from: data)
        } catch {
            throw AuthError.invalidResponse
        }
    }

    private func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let detail = json["detail"] as? String {
            return detail
        }
        return nil
    }
}
