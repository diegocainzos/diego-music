import Foundation

enum YouTubeEndpointError: Error, Equatable {
    case invalidQuery
    case invalidURL
}

enum YouTubeEndpointKind {
    case search(query: String, pageToken: String?)
    case searchPlaylists(query: String, pageToken: String?)
    case channels(ids: [String])
    case playlists(channelID: String, pageToken: String?)
    case playlistItems(playlistID: String, pageToken: String?)
    case mostPopularVideo
}

/// Construye peticiones a YouTube Data API v3. Solo metadatos (snippet).
/// La `apiKey` viaja en el query de forma interna y NUNCA se loguea.
struct YouTubeEndpoint {
    let kind: YouTubeEndpointKind
    let apiKey: String
    let pageToken: String?
    let maxResults: Int

    /// Conveniencia de búsqueda (comportamiento heredado intacto).
    init(query: String, apiKey: String, pageToken: String? = nil, maxResults: Int = 25) {
        self.init(
            kind: .search(query: query, pageToken: pageToken),
            apiKey: apiKey,
            maxResults: maxResults
        )
    }

    init(kind: YouTubeEndpointKind, apiKey: String, maxResults: Int = 25) {
        self.kind = kind
        self.apiKey = apiKey
        self.maxResults = min(max(maxResults, 1), 50)
        switch kind {
        case let .search(_, token),
             let .searchPlaylists(_, token),
             let .playlists(_, token),
             let .playlistItems(_, token):
            self.pageToken = token
        default:
            self.pageToken = nil
        }
    }

    func makeRequest() throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.googleapis.com"

        switch kind {
        case let .search(query, _):
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { throw YouTubeEndpointError.invalidQuery }
            components.path = "/youtube/v3/search"
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "q", normalized),
                URLQueryItem(name: "type", value: "video"),
                URLQueryItem(name: "videoCategoryId", value: "10"),
                URLQueryItem(name: "videoEmbeddable", value: "true"),
                URLQueryItem(name: "safeSearch", value: "moderate"),
                URLQueryItem(name: "maxResults", value: String(maxResults)),
                URLQueryItem(name: "key", value: apiKey)
            ]
            if let pageToken, !pageToken.isEmpty {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
        case let .searchPlaylists(query, _):
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { throw YouTubeEndpointError.invalidQuery }
            components.path = "/youtube/v3/search"
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "q", value: normalized),
                URLQueryItem(name: "type", value: "playlist"),
                URLQueryItem(name: "safeSearch", value: "moderate"),
                URLQueryItem(name: "maxResults", value: String(maxResults)),
                URLQueryItem(name: "key", value: apiKey)
            ]
            if let pageToken, !pageToken.isEmpty {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
        case let .channels(ids):
            components.path = "/youtube/v3/channels"
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "id", value: ids.joined(separator: ",")),
                URLQueryItem(name: "maxResults", value: String(maxResults)),
                URLQueryItem(name: "key", value: apiKey)
            ]
        case let .playlists(channelID, _):
            components.path = "/youtube/v3/playlists"
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "channelId", value: channelID),
                URLQueryItem(name: "maxResults", value: String(maxResults)),
                URLQueryItem(name: "key", value: apiKey)
            ]
            if let pageToken, !pageToken.isEmpty {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
        case let .playlistItems(playlistID, _):
            components.path = "/youtube/v3/playlistItems"
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "playlistId", value: playlistID),
                URLQueryItem(name: "maxResults", value: String(maxResults)),
                URLQueryItem(name: "key", value: apiKey)
            ]
            if let pageToken, !pageToken.isEmpty {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
        case .mostPopularVideo:
            components.path = "/youtube/v3/videos"
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "chart", value: "mostPopular"),
                URLQueryItem(name: "videoCategoryId", value: "10"),
                URLQueryItem(name: "maxResults", value: String(maxResults)),
                URLQueryItem(name: "key", value: apiKey)
            ]
        }

        guard let url = components.url else { throw YouTubeEndpointError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
