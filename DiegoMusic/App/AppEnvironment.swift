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

        // Configurar sincronización en tiempo real desde LibraryStore hacia el Backend
        setupRealtimeLibrarySync(library: library, tokenManager: manager, backendClient: self.backendClient)

        Task {
            await checkInitialAuthState()
        }
    }

    private func setupRealtimeLibrarySync(
        library: LibraryStore,
        tokenManager: any TokenManaging,
        backendClient: any BackendAPIClientProtocol
    ) {
        library.onFavoriteToggled = { [weak self] item, isFav in
            guard let self, let token = tokenManager.getToken(), self.authState.isAuthenticated else { return }
            Task {
                if isFav {
                    _ = try? await backendClient.addFavorite(
                        token: token,
                        entityType: "track",
                        youtubeVideoId: item.id,
                        title: item.title,
                        channelTitle: item.channelTitle,
                        thumbnailUrl: item.thumbnailURL?.absoluteString,
                        durationSeconds: item.durationSeconds
                    )
                } else {
                    _ = try? await backendClient.removeFavorite(
                        token: token,
                        entityType: "track",
                        entityIdentifier: item.id
                    )
                }
            }
        }

        library.onTrackAddedToPlaylist = { [weak self] item, playlist in
            guard let self, let token = tokenManager.getToken(), self.authState.isAuthenticated else { return }
            Task {
                do {
                    let playlists = try await backendClient.fetchMyPlaylists(token: token)
                    let remotePL: BackendPlaylistDTO
                    if let found = playlists.first(where: { $0.name.lowercased() == playlist.name.lowercased() }) {
                        remotePL = found
                    } else {
                        remotePL = try await backendClient.createPlaylist(token: token, name: playlist.name, description: nil, isPublic: false)
                    }
                    _ = try await backendClient.addTrackToPlaylist(
                        token: token,
                        playlistID: remotePL.id,
                        youtubeVideoId: item.id,
                        title: item.title,
                        channelTitle: item.channelTitle,
                        thumbnailUrl: item.thumbnailURL?.absoluteString,
                        durationSeconds: item.durationSeconds,
                        order: nil
                    )
                } catch {
                    print("Error sincronizando adición de canción a playlist en backend: \(error)")
                }
            }
        }

        library.onTrackRemovedFromPlaylist = { [weak self] entry, playlist in
            guard let self, let token = tokenManager.getToken(), self.authState.isAuthenticated else { return }
            Task {
                do {
                    let playlists = try await backendClient.fetchMyPlaylists(token: token)
                    if let remotePL = playlists.first(where: { $0.name.lowercased() == playlist.name.lowercased() }) {
                        try await backendClient.removeTrackFromPlaylist(
                            token: token,
                            playlistID: remotePL.id,
                            trackIdentifier: entry.videoID
                        )
                    }
                } catch {
                    print("Error sincronizando eliminación de canción de playlist en backend: \(error)")
                }
            }
        }

        library.onPlaylistCreated = { [weak self] playlist in
            guard let self, let token = tokenManager.getToken(), self.authState.isAuthenticated else { return }
            Task {
                _ = try? await backendClient.createPlaylist(token: token, name: playlist.name, description: nil, isPublic: false)
            }
        }

        library.onPlaylistDeleted = { [weak self] playlist in
            guard let self, let token = tokenManager.getToken(), self.authState.isAuthenticated else { return }
            Task {
                if let playlists = try? await backendClient.fetchMyPlaylists(token: token),
                   let remotePL = playlists.first(where: { $0.name.lowercased() == playlist.name.lowercased() }) {
                    try? await backendClient.deletePlaylist(token: token, playlistID: remotePL.id)
                }
            }
        }
    }

    func play(_ item: MediaItem) {
        player.select(item)
        if playbackSettings.historyEnabled {
            try? library.addHistory(item)
        }
        TelemetryLogger.shared.recordEvent(type: "track_play", data: ["title": item.title, "artist": item.channelTitle, "video_id": item.id])
        if let token = tokenManager.getToken(), authState.isAuthenticated {
            Task {
                _ = try? await backendClient.recordPlayHistory(
                    token: token,
                    youtubeVideoId: item.id,
                    title: item.title,
                    channelTitle: item.channelTitle,
                    thumbnailUrl: item.thumbnailURL?.absoluteString,
                    durationSeconds: item.durationSeconds,
                    playedSeconds: 0
                )
            }
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
            await syncAllUserDataWithBackend()
        } catch {
            tokenManager.deleteToken()
            library.clearAllUserData()
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
            await syncAllUserDataWithBackend()
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
            await syncAllUserDataWithBackend()
        } catch {
            authState = .unauthenticated
            throw error
        }
    }

    func logout() {
        TelemetryLogger.shared.recordEvent(type: "logout", data: nil)
        tokenManager.deleteToken()
        library.clearAllUserData()
        authState = .unauthenticated
    }

    // MARK: - Sincronización Total de Actividad

    func syncAllUserDataWithBackend() async {
        guard let token = tokenManager.getToken(), authState.isAuthenticated else { return }
        do {
            // 1. Purgar caché local previa para aislar sesión limpia
            library.clearAllUserData()

            // 2. Sincronizar Favoritos desde el backend
            if let remoteFavs = try? await backendClient.fetchFavorites(token: token, entityType: "track") {
                for fav in remoteFavs {
                    if let track = fav.track {
                        let videoID = track.youtubeVideoId ?? "\(track.id)"
                        let title = track.title
                        let channel = track.artist?.name ?? ""
                        let thumb = track.album?.coverURL
                        try? library.importFavorite(videoID: videoID, title: title, channelTitle: channel, thumbnailURLString: thumb)
                    }
                }
            }

            // 3. Sincronizar Playlists y sus pistas desde el backend
            if let remotePlaylists = try? await backendClient.fetchMyPlaylists(token: token) {
                for remote in remotePlaylists {
                    let detailed = (try? await backendClient.fetchPlaylist(token: token, playlistID: remote.id)) ?? remote
                    let entries = detailed.tracks.map { pt in
                        (
                            videoID: pt.track?.youtubeVideoId ?? "\(pt.trackId)",
                            title: pt.track?.title ?? "",
                            channelTitle: pt.track?.artist?.name ?? "",
                            thumbnailURLString: pt.track?.album?.coverURL
                        )
                    }
                    try? library.importPlaylist(name: remote.name, entries: entries)
                }
            }

            // 4. Sincronizar Historial de reproducción desde el backend
            if let remoteHistory = try? await backendClient.fetchPlayHistory(token: token, limit: 50, offset: 0) {
                for hist in remoteHistory {
                    if let track = hist.track {
                        let videoID = track.youtubeVideoId ?? "\(track.id)"
                        let title = track.title
                        let channel = track.artist?.name ?? ""
                        let thumb = track.album?.coverURL
                        try? library.importHistory(videoID: videoID, title: title, channelTitle: channel, thumbnailURLString: thumb)
                    }
                }
            }
        } catch {
            print("Error durante la sincronización total del usuario: \(error)")
        }
    }

    func createPlaylistInBackend(name: String, description: String? = nil) {
        guard let token = tokenManager.getToken(), authState.isAuthenticated else { return }
        Task {
            _ = try? await backendClient.createPlaylist(token: token, name: name, description: description, isPublic: false)
        }
    }
}
