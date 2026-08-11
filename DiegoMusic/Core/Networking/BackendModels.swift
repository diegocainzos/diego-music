import Foundation

// MARK: - Backend Playlist DTOs

public struct BackendPlaylistDTO: Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let description: String?
    public let coverURL: String?
    public let isPublic: Bool
    public let userId: Int
    public let createdAt: String?
    public let updatedAt: String?
    public let tracks: [BackendPlaylistTrackDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case coverURL = "cover_url"
        case isPublic = "is_public"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case tracks
    }

    public init(
        id: Int,
        name: String,
        description: String? = nil,
        coverURL: String? = nil,
        isPublic: Bool = false,
        userId: Int,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        tracks: [BackendPlaylistTrackDTO] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coverURL = coverURL
        self.isPublic = isPublic
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tracks = tracks
    }
}

public struct BackendPlaylistTrackDTO: Codable, Equatable {
    public let playlistId: Int
    public let trackId: Int
    public let order: Int
    public let addedAt: String?
    public let track: BackendTrackDTO?

    enum CodingKeys: String, CodingKey {
        case playlistId = "playlist_id"
        case trackId = "track_id"
        case order
        case addedAt = "added_at"
        case track
    }

    public init(playlistId: Int, trackId: Int, order: Int, addedAt: String? = nil, track: BackendTrackDTO? = nil) {
        self.playlistId = playlistId
        self.trackId = trackId
        self.order = order
        self.addedAt = addedAt
        self.track = track
    }
}

public struct CreatePlaylistRequestPayload: Encodable {
    public let name: String
    public let description: String?
    public let coverURL: String?
    public let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case coverURL = "cover_url"
        case isPublic = "is_public"
    }

    public init(name: String, description: String? = nil, coverURL: String? = nil, isPublic: Bool = false) {
        self.name = name
        self.description = description
        self.coverURL = coverURL
        self.isPublic = isPublic
    }
}

public struct AddTrackToPlaylistPayload: Encodable {
    public let trackId: Int
    public let order: Int?

    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case order
    }

    public init(trackId: Int, order: Int? = 0) {
        self.trackId = trackId
        self.order = order
    }
}

public struct ReorderPlaylistTracksPayload: Encodable {
    public let trackIds: [Int]

    enum CodingKeys: String, CodingKey {
        case trackIds = "track_ids"
    }

    public init(trackIds: [Int]) {
        self.trackIds = trackIds
    }
}

// MARK: - Catalog DTOs

public struct BackendArtistDTO: Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let bio: String?
    public let imageURL: String?
    public let bannerURL: String?
    public let genre: String?
    public let isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case bio
        case imageURL = "image_url"
        case bannerURL = "banner_url"
        case genre
        case isVerified = "is_verified"
    }
}

public struct BackendAlbumDTO: Codable, Identifiable, Equatable {
    public let id: Int
    public let title: String
    public let coverURL: String?
    public let releaseYear: Int?
    public let releaseType: String?
    public let genre: String?
    public let artistId: Int
    public let artist: BackendArtistDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverURL = "cover_url"
        case releaseYear = "release_year"
        case releaseType = "release_type"
        case genre
        case artistId = "artist_id"
        case artist
    }
}

public struct BackendTrackDTO: Codable, Identifiable, Equatable {
    public let id: Int
    public let title: String
    public let durationSeconds: Int
    public let audioURL: String?
    public let youtubeVideoId: String?
    public let trackNumber: Int
    public let discNumber: Int
    public let isExplicit: Bool
    public let lyrics: String?
    public let albumId: Int
    public let artistId: Int
    public let artist: BackendArtistDTO?
    public let album: BackendAlbumDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case durationSeconds = "duration_seconds"
        case audioURL = "audio_url"
        case youtubeVideoId = "youtube_video_id"
        case trackNumber = "track_number"
        case discNumber = "disc_number"
        case isExplicit = "is_explicit"
        case lyrics
        case albumId = "album_id"
        case artistId = "artist_id"
        case artist
        case album
    }
}

public struct CatalogSearchResponseDTO: Codable, Equatable {
    public let query: String
    public let artists: [BackendArtistDTO]
    public let albums: [BackendAlbumDTO]
    public let tracks: [BackendTrackDTO]
}

// MARK: - User Settings & Player State DTOs

public struct UserSettingsDTO: Codable, Equatable {
    public let id: Int
    public let userId: Int
    public let theme: String
    public let audioQuality: String
    public let offlineMode: Bool
    public let explicitContent: Bool
    public let preferredGenres: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case theme
        case audioQuality = "audio_quality"
        case offlineMode = "offline_mode"
        case explicitContent = "explicit_content"
        case preferredGenres = "preferred_genres"
    }
}

public struct UserPlayerStateDTO: Codable, Equatable {
    public let id: Int
    public let userId: Int
    public let currentTrackId: Int?
    public let positionSeconds: Double
    public let playbackStatus: String
    public let shuffleEnabled: Bool
    public let repeatMode: String
    public let queue: [Int]
    public let historyQueue: [Int]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case currentTrackId = "current_track_id"
        case positionSeconds = "position_seconds"
        case playbackStatus = "playback_status"
        case shuffleEnabled = "shuffle_enabled"
        case repeatMode = "repeat_mode"
        case queue
        case historyQueue = "history_queue"
    }
}

public struct UserPlayerStateUpdatePayload: Encodable {
    public let currentTrackId: Int?
    public let positionSeconds: Double?
    public let playbackStatus: String?
    public let shuffleEnabled: Bool?
    public let repeatMode: String?
    public let queue: [Int]?
    public let historyQueue: [Int]?

    enum CodingKeys: String, CodingKey {
        case currentTrackId = "current_track_id"
        case positionSeconds = "position_seconds"
        case playbackStatus = "playback_status"
        case shuffleEnabled = "shuffle_enabled"
        case repeatMode = "repeat_mode"
        case queue
        case historyQueue = "history_queue"
    }

    public init(
        currentTrackId: Int? = nil,
        positionSeconds: Double? = nil,
        playbackStatus: String? = nil,
        shuffleEnabled: Bool? = nil,
        repeatMode: String? = nil,
        queue: [Int]? = nil,
        historyQueue: [Int]? = nil
    ) {
        self.currentTrackId = currentTrackId
        self.positionSeconds = positionSeconds
        self.playbackStatus = playbackStatus
        self.shuffleEnabled = shuffleEnabled
        self.repeatMode = repeatMode
        self.queue = queue
        self.historyQueue = historyQueue
    }
}
