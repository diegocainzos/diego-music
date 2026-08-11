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
    let backendClient: any BackendAPIClientProtocol
    let tokenManager: any TokenManaging

    init(
        modelContext: NSManagedObjectContext,
        transport: any HTTPTransport = URLSessionTransport(),
        authClient: (any AuthClientProtocol)? = nil,
        backendClient: (any BackendAPIClientProtocol)? = nil,
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
        self.backendClient = backendClient ?? BackendAPIClient(baseURL: baseURL, transport: transport)
        TelemetryLogger.shared.configure(baseURL: baseURL, tokenManager: manager)

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
        TelemetryLogger.shared.recordEvent(type: "track_play", data: ["title": item.title, "artist": item.channelTitle, "video_id": item.id])
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

    // MARK: - Autenticación y Sincronización Backend

    func checkInitialAuthState() async {
        guard let token = tokenManager.getToken(), !token.isEmpty else {
            authState = .unauthenticated
            return
        }
        authState = .loading
        do {
            let user = try await authClient.fetchMe(token: token)
            authState = .authenticated(user)
            await syncPlaylistsWithBackend()
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
            TelemetryLogger.shared.recordEvent(type: "login", data: ["email": email])
            await syncPlaylistsWithBackend()
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
            TelemetryLogger.shared.recordEvent(type: "register", data: ["email": email, "full_name": fullName ?? ""])
            await syncPlaylistsWithBackend()
        } catch {
            authState = .unauthenticated
            throw error
        }
    }

    func logout() {
        TelemetryLogger.shared.recordEvent(type: "logout", data: nil)
        tokenManager.deleteToken()
        authState = .unauthenticated
    }

    // MARK: - Sincronización de Playlists

    func syncPlaylistsWithBackend() async {
        guard let token = tokenManager.getToken(), authState.isAuthenticated else { return }
        do {
            let remotePlaylists = try await backendClient.fetchMyPlaylists(token: token)
            for remote in remotePlaylists {
                if !library.playlists.contains(where: { $0.name == remote.name }) {
                    _ = try? library.createPlaylist(named: remote.name)
                }
            }
        } catch {
            print("Sincronización de playlists omitida: \(error)")
        }
    }

    func createPlaylistInBackend(name: String, description: String? = nil) {
        guard let token = tokenManager.getToken(), authState.isAuthenticated else { return }
        Task {
            _ = try? await backendClient.createPlaylist(token: token, name: name, description: description, isPublic: false)
        }
    }
}
