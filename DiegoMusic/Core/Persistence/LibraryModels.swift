import CoreData
import Foundation

struct SavedTrack: Identifiable, Equatable {
    var id: String { videoID }
    let videoID: String
    let title: String
    let channelTitle: String
    let thumbnailURLString: String?
    let savedAt: Date

    var mediaItem: MediaItem {
        MediaItem(
            id: videoID,
            title: title,
            channelTitle: channelTitle,
            thumbnailURL: thumbnailURLString.flatMap(URL.init(string:))
        )
    }
}

struct LocalPlaylist: Identifiable, Equatable {
    let id: UUID
    let name: String
    let createdAt: Date
    let entries: [PlaylistEntry]
}

struct PlaylistEntry: Identifiable, Equatable {
    let id: UUID
    let videoID: String
    let title: String
    let channelTitle: String
    let thumbnailURLString: String?
    let position: Int

    var mediaItem: MediaItem {
        MediaItem(
            id: videoID,
            title: title,
            channelTitle: channelTitle,
            thumbnailURL: thumbnailURLString.flatMap(URL.init(string:))
        )
    }
}

@objc(FavoriteTrackRecord)
final class FavoriteTrackRecord: NSManagedObject {
    @NSManaged var videoID: String
    @NSManaged var title: String
    @NSManaged var channelTitle: String
    @NSManaged var thumbnailURLString: String?
    @NSManaged var savedAt: Date
}

@objc(PlaylistRecord)
final class PlaylistRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
}

@objc(PlaylistEntryRecord)
final class PlaylistEntryRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var playlistID: UUID
    @NSManaged var videoID: String
    @NSManaged var title: String
    @NSManaged var channelTitle: String
    @NSManaged var thumbnailURLString: String?
    @NSManaged var position: Int64
}

@objc(PlaybackHistoryRecord)
final class PlaybackHistoryRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var videoID: String
    @NSManaged var title: String
    @NSManaged var channelTitle: String
    @NSManaged var playedAt: Date
}

@objc(PreferenceRecord)
final class PreferenceRecord: NSManagedObject {
    @NSManaged var key: String
    @NSManaged var value: String
}
