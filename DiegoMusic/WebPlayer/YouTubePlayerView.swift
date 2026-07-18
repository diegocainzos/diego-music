import SwiftUI
import WebKit

#if os(iOS)
struct YouTubePlayerView: UIViewRepresentable {
    @ObservedObject var coordinator: PlayerCoordinator

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: coordinator.makeConfiguration())
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        coordinator.attach(view)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#elseif os(macOS)
struct YouTubePlayerView: NSViewRepresentable {
    @ObservedObject var coordinator: PlayerCoordinator

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: coordinator.makeConfiguration())
        view.setValue(false, forKey: "drawsBackground")
        coordinator.attach(view)
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
