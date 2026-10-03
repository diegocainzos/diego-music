import Foundation

/// Estado global de autenticación en la aplicación.
public enum AuthState: Equatable {
    case unauthenticated
    case loading
    case authenticated(UserDTO)

    public var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}
