import Combine
import CoreData
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let youtubeService: any YouTubeDataServicing
    let queue: PlaybackQueue
    let library: LibraryStore
    let playbackSettings: PlaybackSettings
    let player: AudioPlayerCoordinator
    let resolverConfigured: Bool

    init(modelContext: NSManagedObjectContext, transport: any HTTPTransport = URLSessionTransport()) {
        let library = LibraryStore(context: modelContext)
        let queue = PlaybackQueue()
        let playbackSettings = PlaybackSettings(libraryStore: library)

        let resolver: any AudioStreamResolving
        if let configuration = try? AudioResolverConfiguration.live() {
            resolver = AudioResolverClient(configuration: configuration, transport: transport)
            resolverConfigured = true
        } else {
            resolver = UnavailableAudioResolver()
            resolverConfigured = false
        }

        self.library = library
        self.queue = queue
        self.playbackSettings = playbackSettings
        youtubeService = YouTubeDataService(
            configuration: try? APIConfiguration.live(),
            transport: transport
        )
        player = AudioPlayerCoordinator(queue: queue, resolver: resolver)
    }

    func play(_ item: MediaItem) {
        player.select(item)
        if playbackSettings.historyEnabled {
            try? library.addHistory(item)
        }
    }
}
