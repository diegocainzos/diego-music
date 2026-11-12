import XCTest
@testable import DiegoMusic

/// Criterios de `openspec/changes/unified-library-sync` a nivel de `LibraryStore`.
@MainActor
final class LibraryRestoreTests: XCTestCase {
    /// Cada prueba usa su propio almacén en memoria (instalación limpia).
    private func makeStore() -> LibraryStore {
        LibraryStore(context: PersistenceController(inMemory: true).container.viewContext)
    }

    private func entry(_ id: String) -> (videoID: String, title: String, channelTitle: String, thumbnailURLString: String?) {
        (videoID: id, title: "Pista \(id)", channelTitle: "Canal", thumbnailURLString: nil)
    }

    func testRestoreAfterReinstallKeepsEveryTrack() throws {
        let store = makeStore()

        try store.importPlaylist(remoteID: 7, name: "Gym", entries: [entry("a"), entry("b"), entry("c")])

        XCTAssertEqual(store.playlists.count, 1)
        let playlist = try XCTUnwrap(store.playlists.first(where: { $0.remoteID == 7 }))
        XCTAssertEqual(playlist.name, "Gym")
        XCTAssertEqual(playlist.entries.sorted(by: { $0.position < $1.position }).map(\.videoID), ["a", "b", "c"])
    }

    func testRestoreKeepsSameNamePlaylistsWithDifferentRemoteIDs() throws {
        let store = makeStore()

        try store.importPlaylist(remoteID: 1, name: "Gym", entries: [entry("a")])
        try store.importPlaylist(remoteID: 2, name: "Gym", entries: [entry("b")])

        XCTAssertEqual(Set(store.playlists.compactMap(\.remoteID)), [1, 2])
        XCTAssertEqual(store.playlists.first(where: { $0.remoteID == 1 })?.entries.map(\.videoID), ["a"])
        XCTAssertEqual(store.playlists.first(where: { $0.remoteID == 2 })?.entries.map(\.videoID), ["b"])
    }

    func testHistoryRestoredNewestFirst() throws {
        let store = makeStore()
        let now = Date.now

        // La sincronización recibe el historial del backend del más reciente al más antiguo.
        for (index, id) in ["trackA", "trackB"].enumerated() {
            try store.importHistory(videoID: id, title: id, channelTitle: "Canal", playedAt: now.addingTimeInterval(-Double(index)))
        }

        XCTAssertEqual(store.history.map(\.videoID), ["trackA", "trackB"])
    }

    func testFullRestoreFlow() throws {
        // Flujo compuesto: restaurar playlists + historial, editar y volver a restaurar tras purgar.
        let store = makeStore()
        try store.importPlaylist(remoteID: 7, name: "Gym", entries: [entry("a"), entry("b"), entry("c")])
        try store.importHistory(videoID: "a", title: "a", channelTitle: "Canal", playedAt: .now)

        let restored = try XCTUnwrap(store.playlists.first(where: { $0.remoteID == 7 }))
        try store.add(MediaItem(id: "d", title: "Pista d", channelTitle: "Canal"), to: restored)
        XCTAssertEqual(store.playlists.first(where: { $0.remoteID == 7 })?.entries.map(\.videoID), ["a", "b", "c", "d"])

        store.clearAllUserData()
        try store.importPlaylist(remoteID: 7, name: "Gym", entries: [entry("a"), entry("b"), entry("c"), entry("d")])

        XCTAssertEqual(store.playlists.count, 1)
        XCTAssertEqual(store.playlists.first?.remoteID, 7)
        XCTAssertEqual(store.playlists.first?.entries.map(\.videoID), ["a", "b", "c", "d"])
        XCTAssertTrue(store.history.isEmpty)
    }
}
