import WebKit
import XCTest
@testable import DiegoMusic

final class WebResourcesTests: XCTestCase {
    func testPlayerUsesOfficialIFrameAPIWithoutStreamExtraction() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "player", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(html.contains("https://www.youtube.com/iframe_api"))
        XCTAssertTrue(html.contains("YT.Player"))
        XCTAssertTrue(html.contains("cueVideoById"))
        XCTAssertTrue(html.contains("strict-origin-when-cross-origin"))
        XCTAssertTrue(html.contains(PlayerClientIdentity.placeholder))
        XCTAssertFalse(html.contains("getVideoUrl"))
        XCTAssertFalse(html.contains("googlevideo.com/videoplayback"))
    }

    func testPlayerClientIdentityUsesLowercaseBundleIdentifier() {
        let identity = PlayerClientIdentity(bundleIdentifier: "com.DiegoCainzos.DiegoMusic")
        XCTAssertEqual(identity.origin.absoluteString, "https://com.diegocainzos.diegomusic")
        let prepared = identity.prepare(html: "origin=__APP_ORIGIN__")
        XCTAssertEqual(prepared, "origin=https://com.diegocainzos.diegomusic")
    }

    @MainActor
    func testOfficialPlayerAcceptsBundleIdentity() async throws {
        guard ProcessInfo.processInfo.environment["RUN_YOUTUBE_PLAYER_LIVE_TEST"] == "1" else {
            throw XCTSkip("Prueba live opcional; requiere conexión con YouTube.")
        }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "player", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)
        let identity = PlayerClientIdentity(bundleIdentifier: "com.diegocainzos.DiegoMusic")
        let ready = expectation(description: "IFrame API listo")
        let outcome = expectation(description: "Vídeo preparado o error")
        let probe = PlayerBridgeProbe(ready: ready, outcome: outcome)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(probe, name: "playerBridge")
        let blocker = ContentBlocker(loader: FilterListLoader(bundle: .main))
        let liveMode: ShieldMode = ProcessInfo.processInfo.environment["YOUTUBE_PLAYER_SHIELD_MODE"] == "aggressive"
            ? .aggressive
            : .balanced
        await blocker.apply(
            mode: liveMode,
            customData: nil,
            to: configuration.userContentController
        )
        guard case .active = blocker.state else {
            return XCTFail("PrivacyShield equilibrado no pudo compilar.")
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 270), configuration: configuration)

        webView.loadHTMLString(identity.prepare(html: html), baseURL: identity.origin)
        await fulfillment(of: [ready], timeout: 20)
        _ = try await webView.stringValue(
            for: "window.DieMusicPlayer.receive({type:'load',videoID:'M7lc1UVf-VE'})"
        )
        await fulfillment(of: [outcome], timeout: 20)

        XCTAssertNil(probe.errorCode, "YouTube devolvió el error \(probe.errorCode ?? -1)")
        XCTAssertTrue(probe.states.contains(5) || probe.states.contains(1) || probe.states.contains(2))
    }

    @MainActor
    func testControlledRulesCompileInWebKit() async throws {
        let blocker = ContentBlocker(loader: FilterListLoader(bundle: .main))
        let list = try await blocker.compileControlledList()
        XCTAssertNotNil(list)
    }

    @MainActor
    func testControlledRulesBlockOnlyMarkedResource() async throws {
        let blocker = ContentBlocker(loader: FilterListLoader(bundle: .main))
        let list = try await blocker.compileControlledList()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(list)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let pageURL = try XCTUnwrap(Bundle.main.url(forResource: "controlled-test", withExtension: "html"))
        let waiter = WebViewNavigationWaiter()

        try await waiter.load(webView, url: pageURL)
        try await Task.sleep(nanoseconds: 300_000_000)

        let allowed = try await webView.stringValue(for: "document.getElementById('allowed').textContent")
        let blocked = try await webView.stringValue(for: "document.getElementById('blocked').textContent")
        XCTAssertEqual(allowed, "Recurso permitido: cargado")
        XCTAssertEqual(blocked, "Recurso publicitario: bloqueado")
    }

    @MainActor
    func testBundledShieldModesCompileInWebKit() async {
        for mode in [ShieldMode.balanced, .aggressive] {
            let blocker = ContentBlocker(loader: FilterListLoader(bundle: .main))
            let controller = WKUserContentController()
            await blocker.apply(mode: mode, customData: nil, to: controller)
            guard case .active = blocker.state else {
                return XCTFail("El modo \(mode.rawValue) no compiló en WebKit.")
            }
        }
    }

    @MainActor
    func testFailedRuleUpdatePreservesLastWorkingList() async throws {
        let blocker = ContentBlocker(loader: FilterListLoader(bundle: .main))
        let configuration = WKWebViewConfiguration()
        await blocker.apply(mode: .balanced, customData: nil, to: configuration.userContentController)
        guard case .active = blocker.state else {
            return XCTFail("La lista inicial debía compilar.")
        }
        await blocker.apply(
            mode: .balanced,
            customData: Data("not-json".utf8),
            to: configuration.userContentController
        )
        guard case .failed = blocker.state else {
            return XCTFail("La actualización inválida debía informar un fallo.")
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        let pageURL = try XCTUnwrap(Bundle.main.url(forResource: "controlled-test", withExtension: "html"))
        let waiter = WebViewNavigationWaiter()
        try await waiter.load(webView, url: pageURL)
        try await Task.sleep(nanoseconds: 300_000_000)

        let blocked = try await webView.stringValue(for: "document.getElementById('blocked').textContent")
        XCTAssertEqual(blocked, "Recurso publicitario: bloqueado")
    }

    func testControlledPageContainsAllowedAndBlockedSignals() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "controlled-test", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(html.contains("diegomusic-content-test"))
        XCTAssertTrue(html.contains("diegomusic-ad-test"))
    }
}

private final class WebViewNavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    @MainActor
    func load(_ webView: WKWebView, url: URL) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private final class PlayerBridgeProbe: NSObject, WKScriptMessageHandler {
    private let ready: XCTestExpectation
    private let outcome: XCTestExpectation
    private var didReportReady = false
    private var didReportOutcome = false
    private(set) var errorCode: Int?
    private(set) var states: [Int] = []

    init(ready: XCTestExpectation, outcome: XCTestExpectation) {
        self.ready = ready
        self.outcome = outcome
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        if type == "ready", !didReportReady {
            didReportReady = true
            ready.fulfill()
        } else if type == "error", !didReportOutcome {
            errorCode = body["code"] as? Int
            didReportOutcome = true
            outcome.fulfill()
        } else if type == "state", let state = body["state"] as? Int {
            states.append(state)
            if [1, 2, 5].contains(state), !didReportOutcome {
                didReportOutcome = true
                outcome.fulfill()
            }
        }
    }
}

@MainActor
private extension WKWebView {
    func stringValue(for script: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(script) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: value as? String)
                }
            }
        }
    }
}
