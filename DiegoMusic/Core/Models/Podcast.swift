import Foundation

struct PodcastShow: Identifiable, Equatable, Hashable, Sendable {
    var id: String { channelID }
    let channelID: String
    let title: String
    let thumbnailURL: URL?

    init(channelID: String, title: String, thumbnailURL: URL? = nil) {
        self.channelID = channelID
        self.title = title
        self.thumbnailURL = thumbnailURL
    }
}

struct EpisodeProgressValue: Identifiable, Equatable, Sendable {
    var id: String { videoID }
    let videoID: String
    let channelID: String
    let position: Double
    let duration: Double
    let finished: Bool
    let updatedAt: Date

    init(
        videoID: String,
        channelID: String,
        position: Double,
        duration: Double,
        finished: Bool,
        updatedAt: Date
    ) {
        self.videoID = videoID
        self.channelID = channelID
        self.position = position
        self.duration = duration
        self.finished = finished
        self.updatedAt = updatedAt
    }
}

struct PodcastEpisodePage: Equatable, Sendable {
    let episodes: [MediaItem]
    let hiddenShortCount: Int

    init(episodes: [MediaItem], hiddenShortCount: Int) {
        self.episodes = episodes
        self.hiddenShortCount = hiddenShortCount
    }
}

@MainActor
func seedDefaultShowsIfNeeded(store: LibraryStore, service: any YouTubeDataServicing) async {
    guard store.followedShows().isEmpty else { return }
    guard store.preference(for: "podcasts.seeded") != "true" else { return }

    let defaultQueries = [
        "The Joe Rogan Experience PowerfulJRE",
        "The Wild Project Jordi Wild"
    ]

    var followedAny = false
    for query in defaultQueries {
        do {
            if let show = try await service.searchChannel(query) {
                try store.follow(show)
                followedAny = true
            }
        } catch {
            // Best effort; continuar con el siguiente canal
        }
    }

    if followedAny {
        try? store.setPreference("true", for: "podcasts.seeded")
    }
}
