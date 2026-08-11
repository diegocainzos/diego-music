import Foundation

struct YouTubeMapper {
    func map(_ response: YouTubeSearchResponseDTO) -> SearchPage {
        SearchPage(
            items: response.items.compactMap(map),
            nextPageToken: response.nextPageToken
        )
    }

    func map(_ dto: YouTubeSearchItemDTO) -> MediaItem? {
        guard let id = dto.id.videoId, !id.isEmpty else { return nil }
        return Self.mediaItem(
            id: id,
            title: dto.snippet.title,
            channelTitle: dto.snippet.channelTitle,
            thumbnails: dto.snippet.thumbnails,
            publishedAt: dto.snippet.publishedAt
        )
    }

    func map(_ dto: YouTubeVideoListResponseDTO) -> MediaItem {
        Self.mediaItem(
            id: dto.id,
            title: dto.snippet.title,
            channelTitle: dto.snippet.channelTitle,
            thumbnails: dto.snippet.thumbnails,
            publishedAt: dto.snippet.publishedAt
        )
    }

    func map(_ dto: YouTubePlaylistItemDTO) -> MediaItem? {
        guard let id = dto.snippet.resourceId?.videoId, !id.isEmpty else { return nil }
        return Self.mediaItem(
            id: id,
            title: dto.snippet.title,
            channelTitle: dto.snippet.channelTitle,
            thumbnails: dto.snippet.thumbnails,
            publishedAt: dto.snippet.publishedAt
        )
    }

    func map(_ dto: YouTubeChannelDTO) -> Artist {
        let thumbnail = dto.snippet.thumbnails["high"]
            ?? dto.snippet.thumbnails["medium"]
            ?? dto.snippet.thumbnails["default"]
        return Artist(
            id: dto.id,
            title: dto.snippet.title.decodingHTMLEntities,
            bio: dto.snippet.description?.decodingHTMLEntities,
            thumbnailURL: thumbnail?.url
        )
    }

    private static func mediaItem(
        id: String,
        title: String,
        channelTitle: String,
        thumbnails: [String: YouTubeThumbnail],
        publishedAt: Date?
    ) -> MediaItem {
        let thumbnail = thumbnails["high"]
            ?? thumbnails["medium"]
            ?? thumbnails["default"]
        return MediaItem(
            id: id,
            kind: .video,
            title: title.decodingHTMLEntities,
            channelTitle: channelTitle.decodingHTMLEntities,
            thumbnailURL: thumbnail?.url,
            publishedAt: publishedAt
        )
    }
}

private extension String {
    var decodingHTMLEntities: String {
        guard let data = data(using: .utf8) else { return self }
        return (try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ).string) ?? self
    }
}
