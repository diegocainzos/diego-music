import Foundation

/// Protocolo para el registro asíncrono de eventos de usuario.
public protocol TelemetryLogging: Sendable {
    func recordEvent(type: String, data: [String: Any]?)
}

/// Registrador de telemetría y actividad de usuario en segundo plano no bloqueante.
public final class TelemetryLogger: TelemetryLogging, @unchecked Sendable {
    public static let shared = TelemetryLogger()

    private var baseURL: URL?
    private var tokenManager: (any TokenManaging)?
    private var transport: any HTTPTransport

    public init(
        baseURL: URL? = nil,
        tokenManager: (any TokenManaging)? = nil,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.tokenManager = tokenManager
        self.transport = transport
    }

    public func configure(baseURL: URL, tokenManager: any TokenManaging) {
        self.baseURL = baseURL
        self.tokenManager = tokenManager
    }

    public func recordEvent(type: String, data: [String: Any]? = nil) {
        guard let baseURL = self.baseURL else { return }
        let token = tokenManager?.getToken()

        // Ejecución en segundo plano no bloqueante (priority: .background)
        Task.detached(priority: .background) { [baseURL, token, transport = self.transport] in
            var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/telemetry/events"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = token, !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            var bodyDict: [String: Any] = ["event_type": type]
            if let data = data {
                bodyDict["event_data"] = data
            }

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
                _ = try await transport.data(for: request)
            } catch {
                // Telemetría es best-effort y silenciosa
            }
        }
    }
}
