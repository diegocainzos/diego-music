import Foundation

enum YouTubeEndpointError: Error, Equatable {
    case invalidQuery
    case invalidURL
}

struct YouTubeEndpoint {
    let query: String
    let apiKey: String
    let pageToken: String?
    let maxResults: Int

    init(query: String, apiKey: String, pageToken: String? = nil, maxResults: Int = 25) {
        self.query = query
        self.apiKey = apiKey
        self.pageToken = pageToken
        self.maxResults = min(max(maxResults, 1), 50)
    }

    func makeRequest() throws -> URLRequest {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw YouTubeEndpointError.invalidQuery }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.googleapis.com"
        components.path = "/youtube/v3/search"
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: normalized),
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
        guard let url = components.url else { throw YouTubeEndpointError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
