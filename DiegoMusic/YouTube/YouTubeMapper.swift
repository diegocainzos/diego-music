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
        let thumbnail = dto.snippet.thumbnails["high"]
            ?? dto.snippet.thumbnails["medium"]
            ?? dto.snippet.thumbnails["default"]
        return MediaItem(
            id: id,
            kind: .video,
            title: dto.snippet.title.decodingHTMLEntities,
            channelTitle: dto.snippet.channelTitle.decodingHTMLEntities,
            thumbnailURL: thumbnail?.url,
            publishedAt: dto.snippet.publishedAt
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
