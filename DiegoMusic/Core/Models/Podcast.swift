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
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let position: Double
    let duration: Double
    let finished: Bool
    let updatedAt: Date

    var mediaItem: MediaItem {
        MediaItem(
            id: videoID,
            title: title,
            channelTitle: channelTitle,
            thumbnailURL: thumbnailURL,
            durationSeconds: Int(duration)
        )
    }

    init(
        videoID: String,
        channelID: String,
        title: String,
        channelTitle: String,
        thumbnailURL: URL? = nil,
        position: Double,
        duration: Double,
        finished: Bool,
        updatedAt: Date
    ) {
        self.videoID = videoID
        self.channelID = channelID
        self.title = title
        self.channelTitle = channelTitle
        self.thumbnailURL = thumbnailURL
        self.position = position
        self.duration = duration
        self.finished = finished
        self.updatedAt = updatedAt
    }
}

struct PodcastEpisodePage: Equatable, Sendable {
    let episodes: [MediaItem]
    let hiddenShortCount: Int
    /// Cursor de uploads para pedir episodios más antiguos; nil si no hay más.
    let nextPageToken: String?

    init(episodes: [MediaItem], hiddenShortCount: Int, nextPageToken: String? = nil) {
        self.episodes = episodes
        self.hiddenShortCount = hiddenShortCount
        self.nextPageToken = nextPageToken
    }
}

extension PodcastShow {
    /// Programas fijos: IDs de canal directos, sin gastar cuota en `search.list`.
    static let defaults = [
        PodcastShow(
            channelID: "UCzQUP1qoWDoEbmsQxvdjxgQ",
            title: "The Joe Rogan Experience",
            thumbnailURL: URL(string: "https://yt3.googleusercontent.com/ytc/AIdro_kIOv8XSayB3mVzdmGH6r6nOuncclc_QxWr7TYTXM4dFrs=s400")
        ),
        PodcastShow(
            channelID: "UCBYyJBCtCvgqA4NwtoPMwpQ",
            title: "The Wild Project",
            thumbnailURL: URL(string: "https://yt3.googleusercontent.com/1yaek3C9bqi0LWWOfATgD067T9RuP1rcXxzzObHIYIi0sIcNiyjYo_jYzRtf0eO2UN_GfhXnIg=s400")
        )
    ]
}

/// Sigue JRE y The Wild Project una sola vez; si luego dejas de seguir uno, no vuelve.
/// La clave `v2` re-siembra a quien los perdió por el borrado de la sincronización.
@MainActor
func seedDefaultShowsIfNeeded(store: LibraryStore) {
    let key = "podcasts.defaults.v2"
    guard store.preference(for: key) != "true" else { return }
    for show in PodcastShow.defaults where !store.isFollowing(channelID: show.channelID) {
        try? store.follow(show)
    }
    try? store.setPreference("true", for: key)
}
