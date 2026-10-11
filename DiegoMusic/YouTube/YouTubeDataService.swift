import Foundation

/// Actor thread-safe para gestionar la clave de API activa y rotar automáticamente
/// cuando una clave agote su cuota (error 403 quota / error 429).
actor KeyPool {
    private var keys: [String]
    private var currentIndex: Int = 0

    init(keys: [String]) {
        self.keys = keys
    }

    var hasKeys: Bool { !keys.isEmpty }
    var keyCount: Int { keys.count }

    func currentKey() -> String? {
        guard !keys.isEmpty else { return nil }
        return keys[currentIndex]
    }

    func rotateToNextKey() -> String? {
        guard keys.count > 1 else { return nil }
        currentIndex = (currentIndex + 1) % keys.count
        return keys[currentIndex]
    }
}

enum YouTubeServiceError: LocalizedError, Equatable {
    case missingConfiguration
    case invalidRequest
    case unauthorized
    case quotaExceeded
    case server(status: Int)
    case invalidResponse
    case network
    case unavailable

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Falta configurar YOUTUBE_DATA_KEY localmente."
        case .invalidRequest:
            return "La búsqueda no es válida."
        case .unauthorized:
            return "YouTube rechazó la configuración de acceso. Revisa las restricciones de la clave."
        case .quotaExceeded:
            return "La cuota diaria de YouTube Data API se ha agotado en todas las claves configuradas."
        case .server:
            return "YouTube no está disponible temporalmente."
        case .invalidResponse:
            return "YouTube devolvió una respuesta que no se pudo interpretar."
        case .network:
            return "No se pudo conectar con YouTube. Revisa la conexión."
        case .unavailable:
            return "Esta función de descubrimiento no está disponible."
        }
    }
}

protocol YouTubeDataServicing: Sendable {
    func search(query: String, pageToken: String?) async throws -> SearchPage

    func discover() async throws -> DiscoveryFeed
    func artist(byChannelID: String) async throws -> ArtistDetail
    func album(byPlaylistID: String) async throws -> Album
    func radio(seed videoID: String) async throws -> [MediaItem]
    func podcastEpisodes(channelID: String) async throws -> PodcastEpisodePage
    func searchChannel(_ query: String) async throws -> PodcastShow?
}

struct YouTubeDataService: YouTubeDataServicing {
    private let configuration: APIConfiguration?
    private let resolverConfiguration: AudioResolverConfiguration?
    private let transport: any HTTPTransport
    private let mapper: YouTubeMapper
    private let keyPool: KeyPool
    private let searchCache: SearchCache

    init(
        configuration: APIConfiguration?,
        resolverConfiguration: AudioResolverConfiguration? = nil,
        transport: any HTTPTransport = URLSessionTransport(),
        mapper: YouTubeMapper = YouTubeMapper(),
        searchCache: SearchCache = SearchCache()
    ) {
        self.configuration = configuration
        self.resolverConfiguration = resolverConfiguration
        self.transport = transport
        self.mapper = mapper
        self.keyPool = KeyPool(keys: configuration?.youtubeDataKeys ?? [])
        self.searchCache = searchCache
    }

    func search(query: String, pageToken: String? = nil) async throws -> SearchPage {
        // 1. Comprobar caché local en memoria si es la primera página
        if pageToken == nil, let cached = await searchCache.get(for: query) {
            return cached
        }

        // 2. Intentar consulta a YouTube Data API v3 (con rotación de claves)
        do {
            let data = try await executeWithRotation(
                buildRequest: { apiKey in
                    try endpointRequest {
                        YouTubeEndpoint(query: query, apiKey: apiKey, pageToken: pageToken)
                    }
                },
                responseType: YouTubeSearchResponseDTO.self
            )
            let page = mapper.map(data)
            if pageToken == nil {
                await searchCache.set(page, for: query)
            }
            return page
        } catch YouTubeServiceError.quotaExceeded {
            // 3. Fallback a VPS Resolver si la cuota de YouTube API se agota en todas las claves
            if let fallbackPage = try? await searchVPSService(query: query) {
                if pageToken == nil {
                    await searchCache.set(fallbackPage, for: query)
                }
                return fallbackPage
            }
            throw YouTubeServiceError.quotaExceeded
        }
    }

    func discover() async throws -> DiscoveryFeed {
        let curatedArtistas: [ArtistReference] = [
            ArtistReference(id: "Nas", title: "Nas", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eb51e5f8f94d9326e4f3a743a1")),
            ArtistReference(id: "Karol G", title: "Karol G", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eb987515cf530e37b2d2f7ff00")),
            ArtistReference(id: "Radiohead", title: "Radiohead", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eb8e03e13d987d6056d69103c8")),
            ArtistReference(id: "Daft Punk", title: "Daft Punk", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eb80356bf6f8888062095f9c5d")),
            ArtistReference(id: "Kendrick Lamar", title: "Kendrick Lamar", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eb437b9e2a82505b3d93ff1022")),
            ArtistReference(id: "Taylor Swift", title: "Taylor Swift", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eb5a00969a4698c3132a15fbb0")),
            ArtistReference(id: "Drake", title: "Drake", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eb429124237d6e641bc38615e4")),
            ArtistReference(id: "Eminem", title: "Eminem", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eba00b11c129b27a88fc72f36b")),
            ArtistReference(id: "Rosalía", title: "Rosalía", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5ebc1b0aa4a2f89bb70d9e5b7fb")),
            ArtistReference(id: "The Weeknd", title: "The Weeknd", thumbnailURL: URL(string: "https://i.scdn.co/image/ab6761610000e5eb2143db297e2963690d5c0b11"))
        ]

        let curatedNovedades: [MediaItem] = [
            MediaItem(id: "0WTRRLFjU10", title: "N.Y. State of Mind", channelTitle: "Nas", thumbnailURL: URL(string: "https://i.ytimg.com/vi/0WTRRLFjU10/hqdefault.jpg")),
            MediaItem(id: "AQx_KRoeddI", title: "Si Antes Te Hubiera Conocido", channelTitle: "Karol G", thumbnailURL: URL(string: "https://i.ytimg.com/vi/AQx_KRoeddI/hqdefault.jpg")),
            MediaItem(id: "XFkzRNyyg10", title: "Creep", channelTitle: "Radiohead", thumbnailURL: URL(string: "https://i.ytimg.com/vi/XFkzRNyyg10/hqdefault.jpg")),
            MediaItem(id: "5NV6Rdv1a3I", title: "Get Lucky", channelTitle: "Daft Punk ft. Pharrell Williams", thumbnailURL: URL(string: "https://i.ytimg.com/vi/5NV6Rdv1a3I/hqdefault.jpg")),
            MediaItem(id: "tvTRZJ-4EyI", title: "HUMBLE.", channelTitle: "Kendrick Lamar", thumbnailURL: URL(string: "https://i.ytimg.com/vi/tvTRZJ-4EyI/hqdefault.jpg")),
            MediaItem(id: "3tmd-ClpJxA", title: "Look What You Made Me Do", channelTitle: "Taylor Swift", thumbnailURL: URL(string: "https://i.ytimg.com/vi/3tmd-ClpJxA/hqdefault.jpg")),
            MediaItem(id: "uxpDa-c-4Mc", title: "Hotline Bling", channelTitle: "Drake", thumbnailURL: URL(string: "https://i.ytimg.com/vi/uxpDa-c-4Mc/hqdefault.jpg")),
            MediaItem(id: "_Yhyp-_hX2s", title: "Lose Yourself", channelTitle: "Eminem", thumbnailURL: URL(string: "https://i.ytimg.com/vi/_Yhyp-_hX2s/hqdefault.jpg"))
        ]

        do {
            let data = try await executeWithRotation(
                buildRequest: { apiKey in
                    try endpointRequest {
                        YouTubeEndpoint(kind: .mostPopularVideo, apiKey: apiKey)
                    }
                },
                responseType: YouTubeVideoListEnvelopeDTO.self
            )

            var seenChannelIDs: Set<String> = []
            let fetchedArtistas: [ArtistReference] = data.items.compactMap { (dto: YouTubeVideoListResponseDTO) -> ArtistReference? in
                guard let channelID = dto.snippet.channelId, !channelID.isEmpty else { return nil }
                guard !seenChannelIDs.contains(channelID) else { return nil }
                seenChannelIDs.insert(channelID)
                let thumbnail = dto.snippet.thumbnails["high"]
                    ?? dto.snippet.thumbnails["medium"]
                    ?? dto.snippet.thumbnails["default"]
                return ArtistReference(
                    id: channelID,
                    title: dto.snippet.channelTitle.decodingHTMLEntities,
                    thumbnailURL: thumbnail?.url
                )
            }

            let novedades = data.items.isEmpty ? curatedNovedades : data.items.map(mapper.map)
            let artistas = fetchedArtistas.isEmpty ? curatedArtistas : fetchedArtistas
            return DiscoveryFeed(
                novedades: novedades,
                artistas: artistas
            )
        } catch {
            return DiscoveryFeed(
                novedades: curatedNovedades,
                artistas: curatedArtistas
            )
        }
    }

    func artist(byChannelID channelID: String) async throws -> ArtistDetail {
        guard !channelID.isEmpty else { throw YouTubeServiceError.invalidRequest }

        do {
            if channelID.hasPrefix("UC") {
                if let profileData = try? await executeWithRotation(
                    buildRequest: { apiKey in
                        try endpointRequest { YouTubeEndpoint(kind: .channels(ids: [channelID]), apiKey: apiKey) }
                    },
                    responseType: YouTubeChannelListResponseDTO.self
                ), let artist = profileData.items.first.map(mapper.map) {
                    async let topDataTask = executeWithRotation(
                        buildRequest: { apiKey in
                            try endpointRequest { YouTubeEndpoint(query: artist.title, apiKey: apiKey, maxResults: 20) }
                        },
                        responseType: YouTubeSearchResponseDTO.self
                    )
                    async let playlistDataTask = try? executeWithRotation(
                        buildRequest: { apiKey in
                            try endpointRequest { YouTubeEndpoint(kind: .playlists(channelID: channelID, pageToken: nil), apiKey: apiKey, maxResults: 15) }
                        },
                        responseType: YouTubePlaylistListResponseDTO.self
                    )
                    async let albumSearchTask = try? executeWithRotation(
                        buildRequest: { apiKey in
                            try endpointRequest { YouTubeEndpoint(kind: .searchPlaylists(query: "\(artist.title) album", pageToken: nil), apiKey: apiKey, maxResults: 15) }
                        },
                        responseType: YouTubeSearchResponseDTO.self
                    )
                    async let relatedDataTask = try? executeWithRotation(
                        buildRequest: { apiKey in
                            try endpointRequest { YouTubeEndpoint(kind: .mostPopularVideo, apiKey: apiKey, maxResults: 12) }
                        },
                        responseType: YouTubeVideoListEnvelopeDTO.self
                    )

                    let (topData, playlistData, albumSearchData, relatedData) = await (
                        try topDataTask,
                        playlistDataTask,
                        albumSearchTask,
                        relatedDataTask
                    )

                    var albums: [Album] = []
                    var seenAlbumIDs: Set<String> = []

                    if let channelPlaylists = playlistData?.items.map(mapper.map) {
                        for album in channelPlaylists {
                            if !seenAlbumIDs.contains(album.id) {
                                seenAlbumIDs.insert(album.id)
                                albums.append(album)
                            }
                        }
                    }

                    if let searchedPlaylists = albumSearchData?.items.compactMap(mapper.mapPlaylistSearchItem) {
                        for album in searchedPlaylists {
                            if !seenAlbumIDs.contains(album.id) {
                                seenAlbumIDs.insert(album.id)
                                albums.append(album)
                            }
                        }
                    }

                    return ArtistDetail(
                        artist: artist,
                        topTracks: topData.items.compactMap(mapper.map),
                        related: relatedData?.items.map(mapper.map) ?? [],
                        albums: albums
                    )
                }
            }

            let artistName = channelID
            async let topDataTask = executeWithRotation(
                buildRequest: { apiKey in
                    try endpointRequest { YouTubeEndpoint(query: "\(artistName) tracks", apiKey: apiKey, maxResults: 20) }
                },
                responseType: YouTubeSearchResponseDTO.self
            )
            async let albumSearchTask = try? executeWithRotation(
                buildRequest: { apiKey in
                    try endpointRequest { YouTubeEndpoint(kind: .searchPlaylists(query: "\(artistName) album", pageToken: nil), apiKey: apiKey, maxResults: 15) }
                },
                responseType: YouTubeSearchResponseDTO.self
            )
            async let relatedDataTask = try? executeWithRotation(
                buildRequest: { apiKey in
                    try endpointRequest { YouTubeEndpoint(query: "\(artistName) radio", apiKey: apiKey, maxResults: 12) }
                },
                responseType: YouTubeSearchResponseDTO.self
            )

            let (topData, albumSearchData, relatedData) = await (
                try topDataTask,
                albumSearchTask,
                relatedDataTask
            )

            let topTracks = topData.items.compactMap(mapper.map)
            let artistObj = Artist(
                id: channelID,
                title: artistName,
                bio: "Canal de YouTube",
                thumbnailURL: topTracks.first?.thumbnailURL
            )

            let albums = albumSearchData?.items.compactMap(mapper.mapPlaylistSearchItem) ?? []

            return ArtistDetail(
                artist: artistObj,
                topTracks: topTracks,
                related: relatedData?.items.compactMap(mapper.map) ?? [],
                albums: albums
            )
        } catch {
            if let fallbackDetail = try? await fetchArtistVPSService(artistID: channelID) {
                return fallbackDetail
            }
            throw error
        }
    }

    func album(byPlaylistID playlistID: String) async throws -> Album {
        guard !playlistID.isEmpty else { throw YouTubeServiceError.invalidRequest }

        if playlistID.hasPrefix("PL") || playlistID.hasPrefix("OL") {
            if let data = try? await executeWithRotation(
                buildRequest: { apiKey in
                    try endpointRequest { YouTubeEndpoint(kind: .playlistItems(playlistID: playlistID, pageToken: nil), apiKey: apiKey) }
                },
                responseType: YouTubePlaylistItemsResponseDTO.self
            ) {
                let tracks = data.items.compactMap(mapper.map)
                let first = data.items.first?.snippet
                return Album(
                    id: playlistID,
                    title: first?.title ?? "Álbum / Lista",
                    channelTitle: first?.channelTitle,
                    thumbnailURL: first?.thumbnails["high"]?.url ?? first?.thumbnails["medium"]?.url,
                    tracks: tracks
                )
            }
        }

        let data = try await executeWithRotation(
            buildRequest: { apiKey in
                try endpointRequest { YouTubeEndpoint(query: "\(playlistID) album", apiKey: apiKey, maxResults: 20) }
            },
            responseType: YouTubeSearchResponseDTO.self
        )
        let tracks = data.items.compactMap(mapper.map)
        return Album(
            id: playlistID,
            title: playlistID,
            channelTitle: tracks.first?.channelTitle,
            thumbnailURL: tracks.first?.thumbnailURL,
            tracks: tracks
        )
    }

    func radio(seed videoID: String) async throws -> [MediaItem] {
        guard videoID.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else {
            throw YouTubeServiceError.invalidRequest
        }
        let dto = try await vpsGET(path: "/v1/radio/\(videoID)", decoding: VPSRadioResponseDTO.self)
        return dto.items.map(\.mediaItem)
    }

    // MARK: - Helpers

    private func fetchArtistVPSService(artistID: String) async throws -> ArtistDetail {
        let encodedID = artistID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artistID
        let dto = try await vpsGET(path: "/v1/artist/\(encodedID)", decoding: VPSArtistDetailResponseDTO.self)
        return ArtistDetail(
            artist: Artist(
                id: dto.artist.id,
                title: dto.artist.title,
                bio: dto.artist.bio,
                thumbnailURL: dto.artist.thumbnailURL
            ),
            topTracks: dto.topTracks.map(\.mediaItem),
            related: dto.related.map(\.mediaItem)
        )
    }

    private func searchVPSService(query: String) async throws -> SearchPage {
        let dto = try await vpsGET(
            path: "/v1/search",
            queryItems: [URLQueryItem(name: "q", value: query)],
            decoding: VPSSearchResponseDTO.self
        )
        return SearchPage(items: dto.items.map(\.mediaItem), nextPageToken: nil)
    }

    /// GET autenticado contra el resolutor VPS. Cualquier fallo de configuración,
    /// red o estado se reporta como `quotaExceeded`, que es lo que espera el
    /// fallback de los llamadores.
    private func vpsGET<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        decoding responseType: Response.Type
    ) async throws -> Response {
        guard let resolverConfiguration else { throw YouTubeServiceError.quotaExceeded }

        var components = URLComponents(url: resolverConfiguration.baseURL, resolvingAgainstBaseURL: true)
        components?.path = path
        components?.queryItems = queryItems

        guard let url = components?.url else { throw YouTubeServiceError.quotaExceeded }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(resolverConfiguration.apiToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            throw YouTubeServiceError.quotaExceeded
        }

        guard response.statusCode == 200 else {
            throw YouTubeServiceError.quotaExceeded
        }

        return try JSONDecoder().decode(responseType, from: data)
    }

    private func executeWithRotation<Response: Decodable>(
        buildRequest: (String) throws -> URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        guard await keyPool.hasKeys else { throw YouTubeServiceError.missingConfiguration }

        let totalKeys = await keyPool.keyCount
        var attempts = 0

        while attempts < totalKeys {
            attempts += 1
            guard let apiKey = await keyPool.currentKey() else {
                throw YouTubeServiceError.missingConfiguration
            }

            let request = try buildRequest(apiKey)
            do {
                return try await run(request, response: responseType)
            } catch YouTubeServiceError.quotaExceeded {
                // Con una sola clave `rotateToNextKey()` devuelve nil y el bucle termina.
                _ = await keyPool.rotateToNextKey()
            }
        }
        throw YouTubeServiceError.quotaExceeded
    }

    private func endpointRequest(_ build: () throws -> YouTubeEndpoint) throws -> URLRequest {
        do {
            return try build().makeRequest()
        } catch {
            throw YouTubeServiceError.invalidRequest
        }
    }

    private func run<Response: Decodable>(_ request: URLRequest, response _: Response.Type) async throws -> Response {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            throw YouTubeServiceError.network
        }

        switch response.statusCode {
        case 200..<300:
            guard let decoded = try? JSONDecoder.youtube.decode(Response.self, from: data) else {
                throw YouTubeServiceError.invalidResponse
            }
            return decoded
        case 400:
            throw YouTubeServiceError.invalidRequest
        case 401:
            throw YouTubeServiceError.unauthorized
        case 403:
            if isQuotaError(data) { throw YouTubeServiceError.quotaExceeded }
            throw YouTubeServiceError.unauthorized
        case 429:
            throw YouTubeServiceError.quotaExceeded
        default:
            throw YouTubeServiceError.server(status: response.statusCode)
        }
    }

    private func isQuotaError(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorDict = json["error"] as? [String: Any],
              let errors = errorDict["errors"] as? [[String: Any]] else {
            return false
        }
        return errors.contains { dict in
            let domain = dict["domain"] as? String
            let reason = dict["reason"] as? String
            return domain == "youtube.quota" || reason == "quotaExceeded" || reason == "dailyLimitExceeded"
        }
    }
}

private struct VPSTrackDTO: Decodable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?

    var mediaItem: MediaItem {
        MediaItem(
            id: id,
            kind: .video,
            title: title,
            channelTitle: channelTitle,
            thumbnailURL: thumbnailURL
        )
    }
}

private struct VPSArtistDetailResponseDTO: Decodable {
    struct ArtistDTO: Decodable {
        let id: String
        let title: String
        let bio: String?
        let thumbnailURL: URL?
    }
    let artist: ArtistDTO
    let topTracks: [VPSTrackDTO]
    let related: [VPSTrackDTO]
}

private struct VPSSearchResponseDTO: Decodable {
    let items: [VPSTrackDTO]
}

private struct VPSRadioResponseDTO: Decodable {
    struct Item: Decodable {
        let id: String
        let title: String
        let channel: String
        let durationSeconds: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case channel
            case durationSeconds = "duration_seconds"
        }

        var mediaItem: MediaItem {
            MediaItem(
                id: id,
                title: title,
                channelTitle: channel,
                durationSeconds: durationSeconds
            )
        }
    }

    let items: [Item]
}

// MARK: - Podcasts

extension YouTubeDataService {
    private static let podcastCache = PodcastEpisodesCache()

    func podcastEpisodes(channelID: String) async throws -> PodcastEpisodePage {
        guard !channelID.isEmpty else { throw YouTubeServiceError.invalidRequest }

        if let cached = await Self.podcastCache.get(for: channelID) {
            return cached
        }

        // 1. Canales -> contentDetails.relatedPlaylists.uploads
        let channelData = try await executeWithRotation(
            buildRequest: { apiKey in
                try endpointRequest {
                    YouTubeEndpoint(kind: .channelContentDetails(channelID: channelID), apiKey: apiKey)
                }
            },
            responseType: YouTubeChannelContentDetailsResponseDTO.self
        )

        guard let uploadsPlaylistID = channelData.items.first?.contentDetails?.relatedPlaylists?.uploads,
              !uploadsPlaylistID.isEmpty else {
            return PodcastEpisodePage(episodes: [], hiddenShortCount: 0)
        }

        // 2. PlaylistItems de la lista de uploads (máximo 50)
        let playlistData = try await executeWithRotation(
            buildRequest: { apiKey in
                try endpointRequest {
                    YouTubeEndpoint(kind: .playlistItems(playlistID: uploadsPlaylistID, pageToken: nil), apiKey: apiKey, maxResults: 50)
                }
            },
            responseType: YouTubePlaylistItemsResponseDTO.self
        )

        guard !playlistData.items.isEmpty else {
            return PodcastEpisodePage(episodes: [], hiddenShortCount: 0)
        }

        let itemsWithVideoIDs: [(String, YouTubePlaylistItemDTO)] = playlistData.items.compactMap { item in
            guard let videoID = item.snippet.resourceId?.videoId ?? item.contentDetails?.videoId, !videoID.isEmpty else {
                return nil
            }
            return (videoID, item)
        }

        guard !itemsWithVideoIDs.isEmpty else {
            return PodcastEpisodePage(episodes: [], hiddenShortCount: 0)
        }

        // 3. Videos para obtener duraciones ISO8601
        let videoIDs = itemsWithVideoIDs.map(\.0)
        let videosData = try await executeWithRotation(
            buildRequest: { apiKey in
                try endpointRequest {
                    YouTubeEndpoint(kind: .videos(ids: videoIDs), apiKey: apiKey, maxResults: 50)
                }
            },
            responseType: YouTubeVideoDetailsListResponseDTO.self
        )

        var durationByVideoID: [String: Int] = [:]
        for video in videosData.items {
            if let durationStr = video.contentDetails?.duration,
               let seconds = parseISO8601Duration(durationStr) {
                durationByVideoID[video.id] = seconds
            }
        }

        // 4. Filtrar episodios: durationSeconds >= 2400 (40 minutos), más recientes primero
        var episodes: [MediaItem] = []
        var hiddenShortCount = 0

        for (videoID, playlistItem) in itemsWithVideoIDs {
            let duration = durationByVideoID[videoID] ?? 0
            if duration >= 2400 {
                let snippet = playlistItem.snippet
                let thumbnail = snippet.thumbnails["high"]
                    ?? snippet.thumbnails["medium"]
                    ?? snippet.thumbnails["default"]
                let episode = MediaItem(
                    id: videoID,
                    kind: .video,
                    title: snippet.title.decodingHTMLEntities,
                    channelTitle: snippet.channelTitle.decodingHTMLEntities,
                    thumbnailURL: thumbnail?.url,
                    publishedAt: snippet.publishedAt,
                    durationSeconds: duration
                )
                episodes.append(episode)
            } else {
                hiddenShortCount += 1
            }
        }

        episodes.sort {
            guard let d1 = $0.publishedAt, let d2 = $1.publishedAt else { return false }
            return d1 > d2
        }

        let page = PodcastEpisodePage(episodes: episodes, hiddenShortCount: hiddenShortCount)
        await Self.podcastCache.set(page, for: channelID)
        return page
    }

    func searchChannel(_ query: String) async throws -> PodcastShow? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw YouTubeServiceError.invalidRequest }

        let data = try await executeWithRotation(
            buildRequest: { apiKey in
                try endpointRequest {
                    YouTubeEndpoint(kind: .searchChannels(query: normalized), apiKey: apiKey, maxResults: 1)
                }
            },
            responseType: YouTubeSearchResponseDTO.self
        )

        guard let item = data.items.first,
              let channelID = item.id.channelId ?? item.snippet.channelId,
              !channelID.isEmpty else {
            return nil
        }

        let thumbnail = item.snippet.thumbnails["high"]
            ?? item.snippet.thumbnails["medium"]
            ?? item.snippet.thumbnails["default"]

        return PodcastShow(
            channelID: channelID,
            title: item.snippet.title.decodingHTMLEntities,
            thumbnailURL: thumbnail?.url
        )
    }
}

private actor PodcastEpisodesCache {
    struct Entry: Sendable {
        let page: PodcastEpisodePage
        let timestamp: Date
    }

    private var storage: [String: Entry] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 3600) {
        self.ttl = ttl
    }

    func get(for channelID: String) -> PodcastEpisodePage? {
        guard let entry = storage[channelID] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) < ttl {
            return entry.page
        } else {
            storage.removeValue(forKey: channelID)
            return nil
        }
    }

    func set(_ page: PodcastEpisodePage, for channelID: String) {
        storage[channelID] = Entry(page: page, timestamp: Date())
    }

    func clear() {
        storage.removeAll()
    }
}

/// Parsea una duración en formato ISO 8601 (ej. "PT1H2M3S", "PT40M", "PT20S") a segundos.
func parseISO8601Duration(_ string: String) -> Int? {
    guard string.hasPrefix("P") else { return nil }

    var days = 0
    var hours = 0
    var minutes = 0
    var seconds = 0

    let parts = string.components(separatedBy: "T")
    let datePart = parts[0].dropFirst()
    let timePart = parts.count > 1 ? parts[1] : ""

    if let dIndex = datePart.firstIndex(of: "D") {
        let daysStr = datePart[..<dIndex]
        days = Int(daysStr) ?? 0
    }

    var currentDigits = ""
    for char in timePart {
        if char.isNumber {
            currentDigits.append(char)
        } else if char == "H" {
            hours = Int(currentDigits) ?? 0
            currentDigits = ""
        } else if char == "M" {
            minutes = Int(currentDigits) ?? 0
            currentDigits = ""
        } else if char == "S" {
            seconds = Int(currentDigits) ?? 0
            currentDigits = ""
        }
    }

    let total = days * 86400 + hours * 3600 + minutes * 60 + seconds
    return total >= 0 ? total : nil
}
