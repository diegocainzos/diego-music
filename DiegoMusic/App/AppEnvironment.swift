import Combine
import CoreData
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    /// Referencia compartida débil para que la escena CarPlay (que el sistema
    /// instancia independientemente del ciclo SwiftUI) obtenga player/queue e
    /// inyecte su `configure(player:queue:)` (seam del cambio `carplay`).
    static weak var shared: AppEnvironment?

    @Published var authState: AuthState = .unauthenticated

    let youtubeService: any YouTubeDataServicing
    let queue: PlaybackQueue
    let library: LibraryStore
    let playbackSettings: PlaybackSettings
    let player: AudioPlayerCoordinator
    let resolverConfigured: Bool
    let downloadManager: OfflineDownloadManager
    let networkMonitor: NetworkMonitor
    let authClient: any AuthClientProtocol
    let tokenManager: any TokenManaging

    init(
        modelContext: NSManagedObjectContext,
        transport: any HTTPTransport = URLSessionTransport(),
        authClient: (any AuthClientProtocol)? = nil,
        tokenManager: (any TokenManaging)? = nil
    ) {
        let library = LibraryStore(context: modelContext)
        let queue = PlaybackQueue()
        let playbackSettings = PlaybackSettings(libraryStore: library)

        let resolverConfig = try? AudioResolverConfiguration.live()
        let resolver: any AudioStreamResolving
        if let resolverConfig {
            resolver = AudioResolverClient(configuration: resolverConfig, transport: transport)
            resolverConfigured = true
        } else {
            resolver = UnavailableAudioResolver()
            resolverConfigured = false
        }

        let baseURL = resolverConfig?.baseURL ?? URL(string: "http://localhost:8080")!
        let manager = tokenManager ?? KeychainTokenManager()
        self.tokenManager = manager
        self.authClient = authClient ?? AuthClient(baseURL: baseURL, transport: transport)

        self.library = library
        self.queue = queue
        self.playbackSettings = playbackSettings
        self.downloadManager = OfflineDownloadManager(context: modelContext)
        self.networkMonitor = NetworkMonitor()
        youtubeService = YouTubeDataService(
            configuration: try? APIConfiguration.live(),
            resolverConfiguration: resolverConfig,
            transport: transport
        )
        player = AudioPlayerCoordinator(queue: queue, resolver: resolver, youtubeService: youtubeService)
        player.offlineManager = downloadManager
        player.positionPersister = { [weak playbackSettings] item, seconds in
            playbackSettings?.persist(item: item, seconds: seconds)
        }
        if let restore = playbackSettings.restoreState {
            player.restorePlayback(to: restore.item, at: restore.seconds)
        }
        Self.shared = self

        Task {
            await checkInitialAuthState()
        }
    }

    func play(_ item: MediaItem) {
        player.select(item)
        if playbackSettings.historyEnabled {
            try? library.addHistory(item)
        }
    }

    /// Reemplaza la cola activa por la lista completa dada y comienza la reproducción en `index`.
    func playQueue(_ items: [MediaItem], startingAt index: Int = 0) {
        guard !items.isEmpty else { return }
        let validIndex = items.indices.contains(index) ? index : 0
        queue.replaceQueue(items: items, startIndex: validIndex)
        if let current = queue.current {
            player.select(current)
        }
    }

    // MARK: - Autenticación

    func checkInitialAuthState() async {
        guard let token = tokenManager.getToken(), !token.isEmpty else {
            authState = .unauthenticated
            return
        }
        authState = .loading
        do {
            let user = try await authClient.fetchMe(token: token)
            authState = .authenticated(user)
        } catch {
            tokenManager.deleteToken()
            authState = .unauthenticated
        }
    }

    func login(email: String, password: String) async throws {
        authState = .loading
        do {
            let response = try await authClient.login(email: email, password: password)
            try tokenManager.saveToken(response.accessToken)
            let user = try await authClient.fetchMe(token: response.accessToken)
            authState = .authenticated(user)
        } catch {
            authState = .unauthenticated
            throw error
        }
    }

    func register(email: String, password: String, fullName: String?) async throws {
        authState = .loading
        do {
            let response = try await authClient.register(email: email, password: password, fullName: fullName)
            try tokenManager.saveToken(response.accessToken)
            let user = try await authClient.fetchMe(token: response.accessToken)
            authState = .authenticated(user)
        } catch {
            authState = .unauthenticated
            throw error
        }
    }

    func logout() {
        tokenManager.deleteToken()
        authState = .unauthenticated
    }
}
