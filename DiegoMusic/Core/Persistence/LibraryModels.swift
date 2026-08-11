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

/// Artista local derivado de los registros de favoritos e historial (solo Core Data).
struct LocalArtist: Identifiable, Equatable {
    let name: String
    let tracks: [SavedTrack]

    var id: String { name }
}

/// Álbum local derivado: sin dato de álbum en los registros, se agrupa por
/// artista de forma conservadora (cada artista es un "álbum" local).
struct LocalAlbum: Identifiable, Equatable {
    let name: String
    let tracks: [SavedTrack]

    var id: String { name }
}

/// Álbum guardado explícitamente por el usuario en la biblioteca.
struct SavedAlbum: Identifiable, Equatable {
    let id: String
    let title: String
    let channelTitle: String?
    let thumbnailURLString: String?
    let savedAt: Date

    var thumbnailURL: URL? {
        thumbnailURLString.flatMap(URL.init(string:))
    }

    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let matchesTitle = title.lowercased().contains(q)
        let matchesChannel = channelTitle?.lowercased().contains(q) ?? false
        return matchesTitle || matchesChannel
    }
}

extension SavedTrack {
    /// Coincidencia local por título o artista (y álbum cuando lo hubiera).
    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return title.lowercased().contains(q) || channelTitle.lowercased().contains(q)
    }
}

extension String {
    /// Coincidencia local por nombre de artista, álbum o playlist.
    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return lowercased().contains(q)
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

@objc(SavedAlbumRecord)
final class SavedAlbumRecord: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var title: String
    @NSManaged var channelTitle: String?
    @NSManaged var thumbnailURLString: String?
    @NSManaged var savedAt: Date
}

// MARK: - Descarga Offline

/// Registro Core Data de una pista descargada localmente.
@objc(DownloadedTrackRecord)
final class DownloadedTrackRecord: NSManagedObject {
    @NSManaged var videoID: String
    @NSManaged var title: String
    @NSManaged var channelTitle: String
    @NSManaged var thumbnailURLString: String?
    /// Ruta relativa al directorio de descargas de la app.
    @NSManaged var localFilePath: String
    @NSManaged var fileSizeBytes: Int64
    @NSManaged var downloadedAt: Date
    @NSManaged var contentType: String
}

/// Modelo de valor para exponer pistas descargadas en la UI.
struct DownloadedTrack: Identifiable, Equatable {
    let videoID: String
    let title: String
    let channelTitle: String
    let thumbnailURLString: String?
    let localFilePath: String
    let fileSizeBytes: Int64
    let downloadedAt: Date
    let contentType: String

    var id: String { videoID }

    /// Tamaño formateado para la UI (ej. "3.2 MB").
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }

    var mediaItem: MediaItem {
        MediaItem(
            id: videoID,
            title: title,
            channelTitle: channelTitle,
            thumbnailURL: thumbnailURLString.flatMap(URL.init(string:))
        )
    }
}
