import Combine
import SwiftUI
import WebKit

struct ControlledShieldTestView: View {
    @StateObject private var coordinator: ControlledShieldCoordinator
    @Environment(\.dismiss) private var dismiss

    init(blocker: ContentBlocker) {
        _coordinator = StateObject(wrappedValue: ControlledShieldCoordinator(blocker: blocker))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Laboratorio PrivacyShield").font(.title2.bold())
                    Text("La página comprueba un recurso permitido y otro marcado para bloqueo.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cerrar") { dismiss() }
            }
            .padding()
            ControlledShieldWebView(coordinator: coordinator)
                .overlay {
                    if let message = coordinator.errorMessage {
                        EmptyStateView(
                            title: "No se pudo abrir el laboratorio",
                            symbol: "exclamationmark.triangle",
                            description: message
                        )
                    }
                }
        }
        .background(DiegoTheme.cream)
    }
}

@MainActor
final class ControlledShieldCoordinator: ObservableObject {
    @Published var errorMessage: String?
    private let blocker: ContentBlocker
    private var attached = false

    init(blocker: ContentBlocker) {
        self.blocker = blocker
    }

    func configuration() -> WKWebViewConfiguration { WKWebViewConfiguration() }

    func attach(_ webView: WKWebView) {
        guard !attached else { return }
        attached = true
        Task {
            do {
                let list = try await blocker.compileControlledList()
                webView.configuration.userContentController.add(list)
                guard let url = Bundle.main.url(forResource: "controlled-test", withExtension: "html") else {
                    throw FilterListLoaderError.missingResource("controlled-test")
                }
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Error de compilación de reglas."
            }
        }
    }
}

#if os(iOS)
struct ControlledShieldWebView: UIViewRepresentable {
    @ObservedObject var coordinator: ControlledShieldCoordinator
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: coordinator.configuration())
        coordinator.attach(view)
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#elseif os(macOS)
struct ControlledShieldWebView: NSViewRepresentable {
    @ObservedObject var coordinator: ControlledShieldCoordinator
    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: coordinator.configuration())
        coordinator.attach(view)
        return view
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
