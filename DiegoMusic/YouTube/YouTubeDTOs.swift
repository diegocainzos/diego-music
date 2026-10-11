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
        let thumbnails: [String: YouTubeThumbnail]
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

// MARK: - Playlists (Álbumes / Listas de reproducción)

struct YouTubePlaylistListResponseDTO: Decodable {
    let items: [YouTubePlaylistDTO]
    let nextPageToken: String?
}

struct YouTubePlaylistDTO: Decodable {
    struct Snippet: Decodable {
        let publishedAt: Date?
        let title: String
        let description: String?
        let channelId: String?
        let channelTitle: String
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

    struct ContentDetails: Decodable {
        let videoId: String?
    }

    let id: String
    let snippet: Snippet
    let contentDetails: ContentDetails?
}

// MARK: - Canales (ContentDetails para subidas)

struct YouTubeChannelContentDetailsResponseDTO: Decodable {
    let items: [YouTubeChannelContentDetailsItemDTO]
}

struct YouTubeChannelContentDetailsItemDTO: Decodable {
    struct ContentDetails: Decodable {
        struct RelatedPlaylists: Decodable {
            let uploads: String?
        }
        let relatedPlaylists: RelatedPlaylists?
    }

    let id: String
    let contentDetails: ContentDetails?
}

// MARK: - Vídeos (Detalles de contenido y duración)

struct YouTubeVideoDetailsListResponseDTO: Decodable {
    let items: [YouTubeVideoDetailsItemDTO]
}

struct YouTubeVideoDetailsItemDTO: Decodable {
    struct Snippet: Decodable {
        let publishedAt: Date?
        let title: String
        let channelId: String?
        let channelTitle: String
        let thumbnails: [String: YouTubeThumbnail]
    }

    struct ContentDetails: Decodable {
        let duration: String?
    }

    let id: String
    let snippet: Snippet?
    let contentDetails: ContentDetails?
}

extension JSONDecoder {
    static var youtube: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
