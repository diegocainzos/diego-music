import Combine
import Foundation
import WebKit

@MainActor
final class PlayerCoordinator: NSObject, ObservableObject {
    @Published private(set) var playbackState: PlayerPlaybackState = .unstarted
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?

    private(set) weak var webView: WKWebView?
    private let queue: PlaybackQueue
    private let contentBlocker: ContentBlocker
    private let shieldSettings: ShieldSettings
    private let clientIdentity: PlayerClientIdentity
    private let messageDecoder = PlayerMessageDecoder()
    private var pendingVideoID: String?
    private var configuredWebViewID: ObjectIdentifier?
    private var shieldReloadGeneration = 0

    init(
        queue: PlaybackQueue,
        contentBlocker: ContentBlocker,
        shieldSettings: ShieldSettings,
        clientIdentity: PlayerClientIdentity = .live()
    ) {
        self.queue = queue
        self.contentBlocker = contentBlocker
        self.shieldSettings = shieldSettings
        self.clientIdentity = clientIdentity
    }

    var isPlaying: Bool { playbackState == .playing }
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(WeakScriptMessageHandler(delegate: self), name: "playerBridge")
        configuration.userContentController = controller
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        #endif
        return configuration
    }

    func attach(_ webView: WKWebView) {
        let identifier = ObjectIdentifier(webView)
        guard configuredWebViewID != identifier else { return }
        configuredWebViewID = identifier
        self.webView = webView
        webView.navigationDelegate = self
        Task { await reloadWithCurrentShield() }
    }

    func select(_ item: MediaItem) {
        queue.play(item)
        pendingVideoID = item.id
        sendWhenReady(.load(videoID: item.id))
    }

    func togglePlayback() {
        send(isPlaying ? .pause : .play)
    }

    func next() {
        guard let item = queue.advance() else { return }
        pendingVideoID = item.id
        sendWhenReady(.load(videoID: item.id))
    }

    func previous() {
        guard let item = queue.retreat() else { return }
        pendingVideoID = item.id
        sendWhenReady(.load(videoID: item.id))
    }

    func seek(to progress: Double) {
        guard duration > 0 else { return }
        send(.seek(seconds: min(max(progress, 0), 1) * duration))
    }

    func reloadWithCurrentShield() async {
        guard let webView else { return }
        shieldReloadGeneration += 1
        let generation = shieldReloadGeneration
        isReady = false
        let mode = shieldSettings.mode
        let customRules = shieldSettings.customRulesData
        await contentBlocker.apply(
            mode: mode,
            customData: customRules,
            to: webView.configuration.userContentController
        )
        guard generation == shieldReloadGeneration else { return }
        loadPlayerHTML(in: webView)
    }

    private func loadPlayerHTML(in webView: WKWebView) {
        guard
            let url = Bundle.main.url(forResource: "player", withExtension: "html"),
            let html = try? String(contentsOf: url, encoding: .utf8)
        else {
            errorMessage = "No se encontró el recurso del reproductor."
            return
        }
        webView.loadHTMLString(
            clientIdentity.prepare(html: html),
            baseURL: clientIdentity.origin
        )
    }

    private func sendWhenReady(_ command: PlayerCommand) {
        guard isReady else { return }
        send(command)
    }

    private func send(_ command: PlayerCommand) {
        guard let webView,
              let data = try? JSONEncoder().encode(command),
              let json = String(data: data, encoding: .utf8)
        else { return }
        webView.evaluateJavaScript("window.DieMusicPlayer.receive(\(json));") { [weak self] _, error in
            if error != nil {
                Task { @MainActor in self?.errorMessage = "El reproductor no respondió al control." }
            }
        }
    }

    private func handle(_ event: PlayerEvent) {
        switch event {
        case .ready:
            isReady = true
            errorMessage = nil
            if let videoID = pendingVideoID ?? queue.current?.id {
                send(.load(videoID: videoID))
                pendingVideoID = nil
            }
        case let .stateChanged(state):
            playbackState = state
            if state == .ended { next() }
        case let .progress(current, duration):
            currentTime = max(0, current)
            self.duration = max(0, duration)
        case let .failed(code, _):
            switch code {
            case 152, 153:
                errorMessage = "YouTube rechazó la identidad del reproductor (error \(code ?? 153)). Recarga tras actualizar la aplicación."
            case 101, 150:
                errorMessage = "El propietario no permite reproducir este vídeo fuera de YouTube."
            case 100:
                errorMessage = "El vídeo ya no existe o es privado."
            case 2:
                errorMessage = "YouTube rechazó el identificador del vídeo."
            default:
                errorMessage = code.map { "El reproductor oficial informó el error \($0)." }
                    ?? "El reproductor oficial informó un error."
            }
        }
    }
}

extension PlayerCoordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == "playerBridge",
            message.frameInfo.isMainFrame,
            let event = messageDecoder.decode(body: message.body)
        else { return }
        handle(event)
    }
}

extension PlayerCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        errorMessage = "No se pudo cargar el reproductor oficial."
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        errorMessage = "No se pudo conectar con el reproductor oficial."
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
