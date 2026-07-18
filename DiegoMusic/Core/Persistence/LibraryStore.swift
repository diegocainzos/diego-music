import Combine
import CoreData
import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [SavedTrack] = []
    @Published private(set) var playlists: [LocalPlaylist] = []

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        reload()
    }

    func isFavorite(_ item: MediaItem) -> Bool {
        favorites.contains { $0.videoID == item.id }
    }

    func toggleFavorite(_ item: MediaItem) throws {
        if let existing = try favoriteRecord(videoID: item.id) {
            context.delete(existing)
        } else {
            let record: FavoriteTrackRecord = insertRecord(entityName: "FavoriteTrack")
            record.videoID = item.id
            record.title = item.title
            record.channelTitle = item.channelTitle
            record.thumbnailURLString = item.thumbnailURL?.absoluteString
            record.savedAt = .now
        }
        try saveAndReload()
    }

    func deleteFavorite(_ track: SavedTrack) throws {
        if let record = try favoriteRecord(videoID: track.videoID) {
            context.delete(record)
            try saveAndReload()
        }
    }

    @discardableResult
    func createPlaylist(named name: String) throws -> LocalPlaylist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let record: PlaylistRecord = insertRecord(entityName: "Playlist")
        record.id = UUID()
        record.name = trimmed.isEmpty ? "Nueva playlist" : trimmed
        record.createdAt = .now
        try saveAndReload()
        return playlists.first(where: { $0.id == record.id })!
    }

    func add(_ item: MediaItem, to playlist: LocalPlaylist) throws {
        let currentEntries = try entryRecords(playlistID: playlist.id)
        guard !currentEntries.contains(where: { $0.videoID == item.id }) else { return }
        let record: PlaylistEntryRecord = insertRecord(entityName: "PlaylistEntry")
        record.id = UUID()
        record.playlistID = playlist.id
        record.videoID = item.id
        record.title = item.title
        record.channelTitle = item.channelTitle
        record.thumbnailURLString = item.thumbnailURL?.absoluteString
        record.position = (currentEntries.map(\.position).max() ?? -1) + 1
        try saveAndReload()
    }

    func remove(_ entry: PlaylistEntry, from playlist: LocalPlaylist) throws {
        let records = try entryRecords(playlistID: playlist.id)
        if let record = records.first(where: { $0.id == entry.id }) {
            context.delete(record)
            try normalizePositions(records.filter { $0.id != entry.id })
        }
        try saveAndReload()
    }

    func move(_ entry: PlaylistEntry, in playlist: LocalPlaylist, by offset: Int) throws {
        var records = try entryRecords(playlistID: playlist.id).sorted { $0.position < $1.position }
        guard let source = records.firstIndex(where: { $0.id == entry.id }) else { return }
        let destination = source + offset
        guard records.indices.contains(destination) else { return }
        records.swapAt(source, destination)
        try normalizePositions(records)
        try saveAndReload()
    }

    func delete(_ playlist: LocalPlaylist) throws {
        let request = NSFetchRequest<PlaylistRecord>(entityName: "Playlist")
        if let record = try context.fetch(request).first(where: { $0.id == playlist.id }) {
            context.delete(record)
        }
        for entry in try entryRecords(playlistID: playlist.id) { context.delete(entry) }
        try saveAndReload()
    }

    func addHistory(_ item: MediaItem) throws {
        let record: PlaybackHistoryRecord = insertRecord(entityName: "PlaybackHistory")
        record.id = UUID()
        record.videoID = item.id
        record.title = item.title
        record.channelTitle = item.channelTitle
        record.playedAt = .now
        try context.save()
    }

    func clearHistory() throws {
        let request = NSFetchRequest<PlaybackHistoryRecord>(entityName: "PlaybackHistory")
        for record in try context.fetch(request) { context.delete(record) }
        try context.save()
    }

    func preference(for key: String) -> String? {
        try? preferenceRecord(key: key)?.value
    }

    func setPreference(_ value: String, for key: String) throws {
        if let existing = try preferenceRecord(key: key) {
            existing.value = value
        } else {
            let record: PreferenceRecord = insertRecord(entityName: "Preference")
            record.key = key
            record.value = value
        }
        try context.save()
    }

    func reload() {
        do {
            let favoriteRequest = NSFetchRequest<FavoriteTrackRecord>(entityName: "FavoriteTrack")
            favoriteRequest.sortDescriptors = [NSSortDescriptor(key: "savedAt", ascending: false)]
            favorites = try context.fetch(favoriteRequest).map {
                SavedTrack(
                    videoID: $0.videoID,
                    title: $0.title,
                    channelTitle: $0.channelTitle,
                    thumbnailURLString: $0.thumbnailURLString,
                    savedAt: $0.savedAt
                )
            }

            let entryRequest = NSFetchRequest<PlaylistEntryRecord>(entityName: "PlaylistEntry")
            entryRequest.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true)]
            let entries = try context.fetch(entryRequest)

            let playlistRequest = NSFetchRequest<PlaylistRecord>(entityName: "Playlist")
            playlistRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            playlists = try context.fetch(playlistRequest).map { playlist in
                LocalPlaylist(
                    id: playlist.id,
                    name: playlist.name,
                    createdAt: playlist.createdAt,
                    entries: entries.filter { $0.playlistID == playlist.id }.map {
                        PlaylistEntry(
                            id: $0.id,
                            videoID: $0.videoID,
                            title: $0.title,
                            channelTitle: $0.channelTitle,
                            thumbnailURLString: $0.thumbnailURLString,
                            position: Int($0.position)
                        )
                    }
                )
            }
        } catch {
            favorites = []
            playlists = []
        }
    }

    private func favoriteRecord(videoID: String) throws -> FavoriteTrackRecord? {
        let request = NSFetchRequest<FavoriteTrackRecord>(entityName: "FavoriteTrack")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "videoID == %@", videoID)
        return try context.fetch(request).first
    }

    private func preferenceRecord(key: String) throws -> PreferenceRecord? {
        let request = NSFetchRequest<PreferenceRecord>(entityName: "Preference")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "key == %@", key)
        return try context.fetch(request).first
    }

    private func entryRecords(playlistID: UUID) throws -> [PlaylistEntryRecord] {
        let request = NSFetchRequest<PlaylistEntryRecord>(entityName: "PlaylistEntry")
        request.predicate = NSPredicate(format: "playlistID == %@", playlistID as NSUUID)
        request.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true)]
        return try context.fetch(request)
    }

    private func normalizePositions(_ records: [PlaylistEntryRecord]) throws {
        for (index, record) in records.enumerated() { record.position = Int64(index) }
        if context.hasChanges { try context.save() }
    }

    private func insertRecord<Record: NSManagedObject>(entityName: String) -> Record {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! Record
    }

    private func saveAndReload() throws {
        try context.save()
        reload()
    }
}
