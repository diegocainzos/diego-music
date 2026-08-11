import Foundation

struct YouTubeSearchResponseDTO: Decodable {
    let items: [YouTubeSearchItemDTO]
    let nextPageToken: String?
}

struct YouTubeSearchItemDTO: Decodable {
    struct Identifier: Decodable {
        let kind: String?
        let videoId: String?
        let channelId: String?
        let playlistId: String?
    }

    struct Snippet: Decodable {
        let publishedAt: Date?
        let title: String
        let description: String?
        let channelId: String?
        let channelTitle: String
        let thumbnails: [String: Thumbnail]
    }

    struct Thumbnail: Decodable {
        let url: URL
        let width: Int?
        let height: Int?
    }

    let id: Identifier
    let snippet: Snippet
}

/// Carátula reutilizable compartida por canales/vídeos/playlistItems.
struct YouTubeThumbnail: Decodable {
    let url: URL
    let width: Int?
    let height: Int?
}

// MARK: - Canales

struct YouTubeChannelListResponseDTO: Decodable {
    let items: [YouTubeChannelDTO]
}

struct YouTubeChannelDTO: Decodable {
    struct Snippet: Decodable {
        let title: String
        let description: String?
        let thumbnails: [String: YouTubeThumbnail]
    }

    let id: String
    let snippet: Snippet
}

// MARK: - Vídeos trending / novedades

struct YouTubeVideoListResponseDTO: Decodable {
    struct Snippet: Decodable {
        let publishedAt: Date?
        let title: String
        let channelId: String?
        let channelTitle: String
        let thumbnails: [String: YouTubeThumbnail]
    }

    let id: String
    let snippet: Snippet
}

struct YouTubeVideoListEnvelopeDTO: Decodable {
    let items: [YouTubeVideoListResponseDTO]
    let nextPageToken: String?
}

// MARK: - PlaylistItems (pistas de álbum/lista)

struct YouTubePlaylistItemsResponseDTO: Decodable {
    let items: [YouTubePlaylistItemDTO]
    let nextPageToken: String?
}

struct YouTubePlaylistItemDTO: Decodable {
    struct Snippet: Decodable {
        struct ResourceId: Decodable {
            let videoId: String?
        }

        let publishedAt: Date?
        let title: String
        let channelId: String?
        let channelTitle: String
        let thumbnails: [String: YouTubeThumbnail]
        let resourceId: ResourceId?
    }

    let id: String
    let snippet: Snippet
}

struct YouTubeAPIErrorEnvelopeDTO: Decodable {
    struct Detail: Decodable {
        struct Reason: Decodable {
            let reason: String?
            let message: String?
        }

        let code: Int?
        let message: String?
        let errors: [Reason]?
    }

    let error: Detail
}

extension JSONDecoder {
    static var youtube: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
