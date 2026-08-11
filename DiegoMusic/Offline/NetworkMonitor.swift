import Combine
import Foundation
import Network
import SwiftUI

/// Observa el estado de la conexión de red usando `NWPathMonitor`.
/// Disponible en iOS 12+ / macOS 10.14+, sin permisos adicionales.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.diegocainzos.NetworkMonitor", qos: .utility)

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isConnected != connected {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isConnected = connected
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
