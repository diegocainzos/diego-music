import Foundation

/// Respuesta del endpoint de login/registro del backend `/api/v1/auth/*`.
public struct AuthTokenResponse: Codable, Equatable {
    public let accessToken: String
    public let tokenType: String
    public let userId: Int
    public let email: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case userId = "user_id"
        case email
    }

    public init(accessToken: String, tokenType: String = "bearer", userId: Int, email: String) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.userId = userId
        self.email = email
    }
}

/// DTO de Usuario devuelto por el backend.
public struct UserDTO: Codable, Identifiable, Equatable {
    public let id: Int
    public let email: String
    public let fullName: String?
    public let avatarURL: String?
    public let isActive: Bool
    public let createdAt: String?
    public let lastLoginAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
    }

    public init(
        id: Int,
        email: String,
        fullName: String? = nil,
        avatarURL: String? = nil,
        isActive: Bool = true,
        createdAt: String? = nil,
        lastLoginAt: String? = nil
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.avatarURL = avatarURL
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
    }
}

/// Payload para registro de usuario.
public struct RegisterRequestPayload: Encodable {
    public let email: String
    public let password: String
    public let fullName: String?
    public let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case fullName = "full_name"
        case avatarURL = "avatar_url"
    }

    public init(email: String, password: String, fullName: String? = nil, avatarURL: String? = nil) {
        self.email = email
        self.password = password
        self.fullName = fullName
        self.avatarURL = avatarURL
    }
}

/// Payload para actualización de perfil.
public struct UserUpdatePayload: Encodable {
    public let fullName: String?
    public let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case avatarURL = "avatar_url"
    }

    public init(fullName: String? = nil, avatarURL: String? = nil) {
        self.fullName = fullName
        self.avatarURL = avatarURL
    }
}
