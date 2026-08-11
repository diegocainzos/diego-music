import Combine
import CoreData
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    /// Referencia compartida débil para que la escena CarPlay (que el sistema
    /// instancia independientemente del ciclo SwiftUI) obtenga player/queue e
    /// inyecte su `configure(player:queue:)` (seam del cambio `carplay`).
    static weak var shared: AppEnvironment?

    let youtubeService: any YouTubeDataServicing
    let queue: PlaybackQueue
    let library: LibraryStore
    let playbackSettings: PlaybackSettings
    let player: AudioPlayerCoordinator
    let resolverConfigured: Bool
    let downloadManager: OfflineDownloadManager
    let networkMonitor: NetworkMonitor

    init(modelContext: NSManagedObjectContext, transport: any HTTPTransport = URLSessionTransport()) {
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
    }

    func play(_ item: MediaItem) {
        player.select(item)
        if playbackSettings.historyEnabled {
            try? library.addHistory(item)
        }
    }
}
