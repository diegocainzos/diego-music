import Combine
import CoreData
import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [SavedTrack] = []
    @Published private(set) var playlists: [LocalPlaylist] = []
    @Published private(set) var history: [SavedTrack] = []
    @Published private(set) var savedAlbums: [SavedAlbum] = []

    // Callbacks para sincronización en tiempo real con backend
    var onFavoriteToggled: ((MediaItem, Bool) -> Void)?
    var onTrackAddedToPlaylist: ((MediaItem, LocalPlaylist) -> Void)?
    var onTrackRemovedFromPlaylist: ((PlaylistEntry, LocalPlaylist) -> Void)?
    var onPlaylistCreated: ((LocalPlaylist) -> Void)?
    var onPlaylistDeleted: ((LocalPlaylist) -> Void)?

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        reload()
    }

    func isFavorite(_ item: MediaItem) -> Bool {
        favorites.contains { $0.videoID == item.id }
    }

    func toggleFavorite(_ item: MediaItem) throws {
        let isFav: Bool
        if let existing = try favoriteRecord(videoID: item.id) {
            context.delete(existing)
            isFav = false
        } else {
            let record: FavoriteTrackRecord = insertRecord(entityName: "FavoriteTrack")
            record.videoID = item.id
            record.title = item.title
            record.channelTitle = item.channelTitle
            record.thumbnailURLString = item.thumbnailURL?.absoluteString
            record.savedAt = .now
            isFav = true
        }
        try saveAndReload()
        onFavoriteToggled?(item, isFav)
    }

    func deleteFavorite(_ track: SavedTrack) throws {
        if let record = try favoriteRecord(videoID: track.videoID) {
            context.delete(record)
            try saveAndReload()
        }
    }

    // MARK: - Álbumes Guardados

    func isAlbumSaved(id: String) -> Bool {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return savedAlbums.contains {
            $0.id.lowercased() == trimmed || $0.title.lowercased() == trimmed
        }
    }

    func toggleSaveAlbum(_ album: Album) throws {
        try toggleSaveAlbum(
            id: album.id,
            title: album.title,
            channelTitle: album.channelTitle,
            thumbnailURL: album.thumbnailURL,
            tracks: album.tracks
        )
    }

    func toggleSaveAlbum(
        id: String,
        title: String,
        channelTitle: String?,
        thumbnailURL: URL?,
        tracks: [MediaItem] = []
    ) throws {
        if let existing = try savedAlbumRecord(id: id) {
            context.delete(existing)
        } else {
            let record: SavedAlbumRecord = insertRecord(entityName: "SavedAlbum")
            record.id = id
            record.title = title
            record.channelTitle = channelTitle
            record.thumbnailURLString = thumbnailURL?.absoluteString
            record.savedAt = .now

            for track in tracks {
                if !isFavorite(track) {
                    let trackRecord: FavoriteTrackRecord = insertRecord(entityName: "FavoriteTrack")
                    trackRecord.videoID = track.id
                    trackRecord.title = track.title
                    trackRecord.channelTitle = track.channelTitle
                    trackRecord.thumbnailURLString = track.thumbnailURL?.absoluteString
                    trackRecord.savedAt = .now
                }
            }
        }
        try saveAndReload()
    }

    func deleteSavedAlbum(id: String) throws {
        if let record = try savedAlbumRecord(id: id) {
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
        let created = playlists.first(where: { $0.id == record.id })!
        onPlaylistCreated?(created)
        return created
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
        onTrackAddedToPlaylist?(item, playlist)
    }

    func remove(_ entry: PlaylistEntry, from playlist: LocalPlaylist) throws {
        let records = try entryRecords(playlistID: playlist.id)
        if let record = records.first(where: { $0.id == entry.id }) {
            context.delete(record)
            try normalizePositions(records.filter { $0.id != entry.id })
        }
        try saveAndReload()
        onTrackRemovedFromPlaylist?(entry, playlist)
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
        onPlaylistDeleted?(playlist)
    }

    func rename(_ playlist: LocalPlaylist, to newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let request = NSFetchRequest<PlaylistRecord>(entityName: "Playlist")
        if let record = try context.fetch(request).first(where: { $0.id == playlist.id }) {
            record.name = trimmed
            try saveAndReload()
        }
    }

    // MARK: - Agregación derivada (solo local)

    /// Canciones de la biblioteca: favoritos sin duplicar por vídeo.
    var songs: [SavedTrack] { favorites }

    /// Artistas locales agrupados por `channelTitle` (favoritos e historial).
    var artists: [LocalArtist] {
        let source = favorites + history
        var groups: [String: [SavedTrack]] = [:]
        for track in source { groups[track.channelTitle, default: []].append(track) }
        return groups
            .map { LocalArtist(name: $0.key, tracks: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Álbumes locales derivados de forma conservadora (grupo por artista),
    /// dado que los registros no almacenan un dato de álbum real.
    var albums: [LocalAlbum] {
        artists.map { LocalAlbum(name: $0.name, tracks: $0.tracks) }
    }

    /// Heurística local de recomendaciones: canciones favoritas de los
    /// artistas más reproducidos en el historial, priorizadas por frecuencia.
    /// Solo local, sin red.
    var recommendations: [SavedTrack] {
        var artistFreq: [String: Int] = [:]
        for track in history { artistFreq[track.channelTitle, default: 0] += 1 }

        let rankedArtists = artistFreq.sorted { $0.value > $1.value }.map(\.key)
        var seen = Set<String>()
        var result: [SavedTrack] = []

        // Canciones marcadas como favorito de los artistas más escuchados.
        for artist in rankedArtists {
            for track in favorites where track.channelTitle == artist && !seen.contains(track.videoID) {
                seen.insert(track.videoID)
                result.append(track)
                if result.count >= 12 { return result }
            }
        }
        return result
    }

    func addHistory(_ item: MediaItem) throws {
        let record: PlaybackHistoryRecord = insertRecord(entityName: "PlaybackHistory")
        record.id = UUID()
        record.videoID = item.id
        record.title = item.title
        record.channelTitle = item.channelTitle
        record.thumbnailURLString = item.thumbnailURL?.absoluteString
        record.playedAt = .now
        try saveAndReload()
    }

    func clearHistory() throws {
        let request = NSFetchRequest<PlaybackHistoryRecord>(entityName: "PlaybackHistory")
        for record in try context.fetch(request) { context.delete(record) }
        try saveAndReload()
    }

    // MARK: - Sincronización y Limpieza de Usuario

    /// Purga todos los registros de usuario locales (favoritos, playlists, entradas, historial, álbumes guardados).
    func clearAllUserData() {
        let entityNames = ["FavoriteTrack", "Playlist", "PlaylistEntry", "PlaybackHistory", "SavedAlbum"]
        for name in entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            if let objects = try? context.fetch(request) {
                for obj in objects {
                    context.delete(obj)
                }
            }
        }
        try? saveAndReload()
    }

    /// Importa o actualiza un favorito desde el backend.
    func importFavorite(videoID: String, title: String, channelTitle: String, thumbnailURLString: String? = nil, savedAt: Date = .now) throws {
        if let existing = try favoriteRecord(videoID: videoID) {
            existing.title = title
            existing.channelTitle = channelTitle
            existing.thumbnailURLString = thumbnailURLString
        } else {
            let record: FavoriteTrackRecord = insertRecord(entityName: "FavoriteTrack")
            record.videoID = videoID
            record.title = title
            record.channelTitle = channelTitle
            record.thumbnailURLString = thumbnailURLString
            record.savedAt = savedAt
        }
        try saveAndReload()
    }

    /// Importa o actualiza una playlist completa con sus pistas desde el backend.
    func importPlaylist(name: String, entries: [(videoID: String, title: String, channelTitle: String, thumbnailURLString: String?)]) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let request = NSFetchRequest<PlaylistRecord>(entityName: "Playlist")
        request.predicate = NSPredicate(format: "name ==[c] %@", trimmed)
        let playlistRecord: PlaylistRecord
        if let existing = try context.fetch(request).first {
            playlistRecord = existing
            let oldEntries = try entryRecords(playlistID: existing.id)
            for old in oldEntries { context.delete(old) }
        } else {
            playlistRecord = insertRecord(entityName: "Playlist")
            playlistRecord.id = UUID()
            playlistRecord.name = trimmed
            playlistRecord.createdAt = .now
        }

        for (index, entry) in entries.enumerated() {
            let entryRecord: PlaylistEntryRecord = insertRecord(entityName: "PlaylistEntry")
            entryRecord.id = UUID()
            entryRecord.playlistID = playlistRecord.id
            entryRecord.videoID = entry.videoID
            entryRecord.title = entry.title
            entryRecord.channelTitle = entry.channelTitle
            entryRecord.thumbnailURLString = entry.thumbnailURLString
            entryRecord.position = Int64(index)
        }

        try saveAndReload()
    }

    /// Importa un registro de historial desde el backend.
    func importHistory(videoID: String, title: String, channelTitle: String, thumbnailURLString: String? = nil, playedAt: Date = .now) throws {
        let record: PlaybackHistoryRecord = insertRecord(entityName: "PlaybackHistory")
        record.id = UUID()
        record.videoID = videoID
        record.title = title
        record.channelTitle = channelTitle
        record.thumbnailURLString = thumbnailURLString
        record.playedAt = playedAt
        try saveAndReload()
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

            let historyRequest = NSFetchRequest<PlaybackHistoryRecord>(entityName: "PlaybackHistory")
            historyRequest.sortDescriptors = [NSSortDescriptor(key: "playedAt", ascending: false)]
            history = try context.fetch(historyRequest).map {
                SavedTrack(
                    videoID: $0.videoID,
                    title: $0.title,
                    channelTitle: $0.channelTitle,
                    thumbnailURLString: $0.thumbnailURLString,
                    savedAt: $0.playedAt
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

            let savedAlbumRequest = NSFetchRequest<SavedAlbumRecord>(entityName: "SavedAlbum")
            savedAlbumRequest.sortDescriptors = [NSSortDescriptor(key: "savedAt", ascending: false)]
            savedAlbums = (try? context.fetch(savedAlbumRequest))?.map {
                SavedAlbum(
                    id: $0.id,
                    title: $0.title,
                    channelTitle: $0.channelTitle,
                    thumbnailURLString: $0.thumbnailURLString,
                    savedAt: $0.savedAt
                )
            } ?? []
        } catch {
            favorites = []
            playlists = []
            history = []
            savedAlbums = []
        }
    }

    private func favoriteRecord(videoID: String) throws -> FavoriteTrackRecord? {
        let request = NSFetchRequest<FavoriteTrackRecord>(entityName: "FavoriteTrack")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "videoID == %@", videoID)
        return try context.fetch(request).first
    }

    private func savedAlbumRecord(id: String) throws -> SavedAlbumRecord? {
        let request = NSFetchRequest<SavedAlbumRecord>(entityName: "SavedAlbum")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@ OR title ==[c] %@", id, id)
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
