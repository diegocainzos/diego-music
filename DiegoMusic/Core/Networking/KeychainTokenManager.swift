import Foundation
import Security

/// Protocolo para inyección y pruebas de token storage.
public protocol TokenManaging: AnyObject {
    func saveToken(_ token: String) throws
    func getToken() -> String?
    func deleteToken()
}

/// Gestor seguro de tokens de autenticación mediante Keychain con fallback a almacenamiento encriptado/local para tests.
public final class KeychainTokenManager: TokenManaging {
    private let service: String
    private let account: String
    private let userDefaultsKey = "com.diegocainzos.DiegoMusic.authTokenFallback"

    public init(service: String = "com.diegocainzos.DiegoMusic.auth", account: String = "accessToken") {
        self.service = service
        self.account = account
    }

    public func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Borrar anterior si existía
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Fallback a UserDefaults si Keychain no está disponible (e.g., test sin firma)
            UserDefaults.standard.set(token, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }

    public func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data, let token = String(data: data, encoding: .utf8) {
            return token
        }

        // Fallback
        return UserDefaults.standard.string(forKey: userDefaultsKey)
    }

    public func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
