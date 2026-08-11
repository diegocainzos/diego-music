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

    public var currentUser: UserDTO? {
        if case let .authenticated(user) = self { return user }
        return nil
    }
}
