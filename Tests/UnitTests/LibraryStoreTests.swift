import XCTest
@testable import DiegoMusic

@MainActor
final class LibraryStoreTests: XCTestCase {
    private static let persistence = PersistenceController(inMemory: true)
    func testFavoritesToggleWithoutDuplicates() throws {
        let store = makeStore()
        let item = MediaItem(id: "video", title: "Pieza", channelTitle: "Canal")

        try store.toggleFavorite(item)
        XCTAssertEqual(store.favorites.map(\.videoID), ["video"])
        try store.toggleFavorite(item)
        XCTAssertTrue(store.favorites.isEmpty)
    }

    func testPlaylistRejectsDuplicateVideo() throws {
        let store = makeStore()
        let playlist = try store.createPlaylist(named: "Bauhaus")
        let item = MediaItem(id: "video", title: "Pieza", channelTitle: "Canal")

        try store.add(item, to: playlist)
        try store.add(item, to: playlist)

        XCTAssertEqual(store.playlists.first?.entries.count, 1)
    }

    func testPlaylistCanReorderAndRemoveEntries() throws {
        let store = makeStore()
        let playlist = try store.createPlaylist(named: "Orden")
        let first = MediaItem(id: "one", title: "Uno", channelTitle: "Canal")
        let second = MediaItem(id: "two", title: "Dos", channelTitle: "Canal")
        try store.add(first, to: playlist)
        try store.add(second, to: playlist)

        var refreshed = try XCTUnwrap(store.playlists.first(where: { $0.id == playlist.id }))
        let secondEntry = try XCTUnwrap(refreshed.entries.first(where: { $0.videoID == second.id }))
        try store.move(secondEntry, in: refreshed, by: -1)
        refreshed = try XCTUnwrap(store.playlists.first(where: { $0.id == playlist.id }))
        XCTAssertEqual(refreshed.entries.sorted(by: { $0.position < $1.position }).map(\.videoID), ["two", "one"])

        let firstEntry = try XCTUnwrap(refreshed.entries.first(where: { $0.videoID == first.id }))
        try store.remove(firstEntry, from: refreshed)
        XCTAssertEqual(store.playlists.first(where: { $0.id == playlist.id })?.entries.map(\.videoID), ["two"])
    }

    func testPreferencePersistsInContext() throws {
        let store = makeStore()
        try store.setPreference("true", for: "playback.historyEnabled")
        XCTAssertEqual(store.preference(for: "playback.historyEnabled"), "true")
    }

    private func makeStore() -> LibraryStore {
        LibraryStore(context: Self.persistence.container.viewContext)
    }
}
