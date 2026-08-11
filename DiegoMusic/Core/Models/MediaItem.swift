import Foundation

enum MediaKind: String, Codable, CaseIterable, Sendable {
    case video
    case channel
    case playlist
}

struct MediaItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: MediaKind
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let publishedAt: Date?

    init(
        id: String,
        kind: MediaKind = .video,
        title: String,
        channelTitle: String,
        thumbnailURL: URL? = nil,
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.channelTitle = channelTitle
        if let thumbnailURL {
            self.thumbnailURL = thumbnailURL
        } else if kind == .video, !id.isEmpty {
            self.thumbnailURL = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
        } else {
            self.thumbnailURL = nil
        }
        self.publishedAt = publishedAt
    }
}

struct SearchPage: Equatable, Sendable {
    let items: [MediaItem]
    let nextPageToken: String?
}

enum SearchPresentationState: Equatable {
    case idle
    case loading
    case loaded([MediaItem])
    case empty
    case failed(message: String)
}
