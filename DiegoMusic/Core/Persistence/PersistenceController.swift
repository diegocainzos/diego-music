import CoreData
import Foundation

final class PersistenceController {
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "DiegoMusic",
            managedObjectModel: Self.makeModel()
        )
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.persistentStoreDescriptions.forEach {
            $0.shouldMigrateStoreAutomatically = true
            $0.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { _, error in
            precondition(error == nil, "No se pudo preparar el almacén local de DiegoMusic.")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            entity("FavoriteTrack", FavoriteTrackRecord.self, [
                attribute("videoID", .stringAttributeType),
                attribute("title", .stringAttributeType),
                attribute("channelTitle", .stringAttributeType),
                attribute("thumbnailURLString", .stringAttributeType, optional: true),
                attribute("savedAt", .dateAttributeType)
            ], uniqueness: [["videoID"]]),
            entity("Playlist", PlaylistRecord.self, [
                attribute("id", .UUIDAttributeType),
                attribute("name", .stringAttributeType),
                attribute("createdAt", .dateAttributeType)
            ], uniqueness: [["id"]]),
            entity("PlaylistEntry", PlaylistEntryRecord.self, [
                attribute("id", .UUIDAttributeType),
                attribute("playlistID", .UUIDAttributeType),
                attribute("videoID", .stringAttributeType),
                attribute("title", .stringAttributeType),
                attribute("channelTitle", .stringAttributeType),
                attribute("thumbnailURLString", .stringAttributeType, optional: true),
                attribute("position", .integer64AttributeType)
            ], uniqueness: [["playlistID", "videoID"]]),
            entity("PlaybackHistory", PlaybackHistoryRecord.self, [
                attribute("id", .UUIDAttributeType),
                attribute("videoID", .stringAttributeType),
                attribute("title", .stringAttributeType),
                attribute("channelTitle", .stringAttributeType),
                attribute("playedAt", .dateAttributeType)
            ], uniqueness: [["id"]]),
            entity("Preference", PreferenceRecord.self, [
                attribute("key", .stringAttributeType),
                attribute("value", .stringAttributeType)
            ], uniqueness: [["key"]]),
            entity("SavedAlbum", SavedAlbumRecord.self, [
                attribute("id", .stringAttributeType),
                attribute("title", .stringAttributeType),
                attribute("channelTitle", .stringAttributeType, optional: true),
                attribute("thumbnailURLString", .stringAttributeType, optional: true),
                attribute("savedAt", .dateAttributeType)
            ], uniqueness: [["id"]]),
            entity("DownloadedTrack", DownloadedTrackRecord.self, [
                attribute("videoID", .stringAttributeType),
                attribute("title", .stringAttributeType),
                attribute("channelTitle", .stringAttributeType),
                attribute("thumbnailURLString", .stringAttributeType, optional: true),
                attribute("localFilePath", .stringAttributeType),
                attribute("fileSizeBytes", .integer64AttributeType),
                attribute("downloadedAt", .dateAttributeType),
                attribute("contentType", .stringAttributeType)
            ], uniqueness: [["videoID"]])
        ]
        return model
    }

    private static func entity(
        _ name: String,
        _ objectType: NSManagedObject.Type,
        _ properties: [NSPropertyDescription],
        uniqueness: [[String]]
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(objectType)
        entity.properties = properties
        entity.uniquenessConstraints = uniqueness
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}
