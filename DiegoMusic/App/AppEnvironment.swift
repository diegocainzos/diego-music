import Combine
import CoreData
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let youtubeService: any YouTubeDataServicing
    let queue: PlaybackQueue
    let library: LibraryStore
    let playbackSettings: PlaybackSettings
    let shieldSettings: ShieldSettings
    let contentBlocker: ContentBlocker
    let player: PlayerCoordinator

    init(modelContext: NSManagedObjectContext, transport: any HTTPTransport = URLSessionTransport()) {
        let library = LibraryStore(context: modelContext)
        let queue = PlaybackQueue()
        let playbackSettings = PlaybackSettings(libraryStore: library)
        let shieldSettings = ShieldSettings(libraryStore: library)
        let contentBlocker = ContentBlocker()
        let configuration = try? APIConfiguration.live()

        self.library = library
        self.queue = queue
        self.playbackSettings = playbackSettings
        self.shieldSettings = shieldSettings
        self.contentBlocker = contentBlocker
        youtubeService = YouTubeDataService(configuration: configuration, transport: transport)
        player = PlayerCoordinator(
            queue: queue,
            contentBlocker: contentBlocker,
            shieldSettings: shieldSettings
        )
    }

    func play(_ item: MediaItem) {
        player.select(item)
        if playbackSettings.historyEnabled {
            try? library.addHistory(item)
        }
    }

    func refreshShield() async {
        await player.reloadWithCurrentShield()
    }
}
