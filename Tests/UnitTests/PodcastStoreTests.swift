import XCTest
@testable import DiegoMusic

@MainActor
final class PodcastStoreTests: XCTestCase {
    private static let persistence = PersistenceController(inMemory: true)

    private func makeStore() -> LibraryStore {
        let store = LibraryStore(context: Self.persistence.container.viewContext)
        store.clearAllUserData()
        try? store.setPreference("false", for: "podcasts.defaults.v2")
        return store
    }

    func testFollowAndUnfollowShow() throws {
        let store = makeStore()
        let show = PodcastShow(
            channelID: "UC_TEST_1",
            title: "Test Podcast Show",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg")
        )

        XCTAssertFalse(store.isFollowing(channelID: show.channelID))
        XCTAssertTrue(store.followedShows().isEmpty)

        try store.follow(show)

        XCTAssertTrue(store.isFollowing(channelID: show.channelID))
        let followed = store.followedShows()
        XCTAssertEqual(followed.count, 1)
        XCTAssertEqual(followed.first?.channelID, show.channelID)
        XCTAssertEqual(followed.first?.title, "Test Podcast Show")
        XCTAssertEqual(followed.first?.thumbnailURL, URL(string: "https://example.com/thumb.jpg"))

        // Re-seguir actualizando el título no crea duplicados
        let updatedShow = PodcastShow(channelID: "UC_TEST_1", title: "Updated Title")
        try store.follow(updatedShow)
        XCTAssertEqual(store.followedShows().count, 1)
        XCTAssertEqual(store.followedShows().first?.title, "Updated Title")

        // Dejar de seguir
        try store.unfollow(channelID: show.channelID)
        XCTAssertFalse(store.isFollowing(channelID: show.channelID))
        XCTAssertTrue(store.followedShows().isEmpty)
    }

    func testSaveAndRetrieveProgress() throws {
        let store = makeStore()

        XCTAssertNil(store.progress(videoID: "vid_1"))

        let item = MediaItem(
            id: "vid_1",
            title: "Episodio de prueba",
            channelTitle: "Canal Podcast",
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            durationSeconds: 3600
        )
        try store.saveProgress(item: item, channelID: "ch_1", position: 120.5, duration: 3600.0)

        let progress = try XCTUnwrap(store.progress(videoID: "vid_1"))
        XCTAssertEqual(progress.videoID, "vid_1")
        XCTAssertEqual(progress.channelID, "ch_1")
        XCTAssertEqual(progress.title, "Episodio de prueba")
        XCTAssertEqual(progress.channelTitle, "Canal Podcast")
        XCTAssertEqual(progress.thumbnailURL, URL(string: "https://example.com/thumb.jpg"))
        XCTAssertEqual(progress.position, 120.5)
        XCTAssertEqual(progress.duration, 3600.0)
        XCTAssertFalse(progress.finished)

        let mediaItem = progress.mediaItem
        XCTAssertEqual(mediaItem.id, "vid_1")
        XCTAssertEqual(mediaItem.title, "Episodio de prueba")
        XCTAssertEqual(mediaItem.channelTitle, "Canal Podcast")
        XCTAssertEqual(mediaItem.thumbnailURL, URL(string: "https://example.com/thumb.jpg"))
        XCTAssertEqual(mediaItem.durationSeconds, 3600)
    }

    func testFinishedThresholdCalculation() throws {
        let store = makeStore()

        // 61 segundos restantes -> finished = false
        let itemUnfinished = MediaItem(id: "vid_unfinished", title: "Unfinished", channelTitle: "ch_1")
        try store.saveProgress(item: itemUnfinished, channelID: "ch_1", position: 939.0, duration: 1000.0)
        let unfinished = try XCTUnwrap(store.progress(videoID: "vid_unfinished"))
        XCTAssertFalse(unfinished.finished)

        // Exactamente 60 segundos restantes -> finished = true
        let itemExact = MediaItem(id: "vid_finished_exact", title: "Exact", channelTitle: "ch_1")
        try store.saveProgress(item: itemExact, channelID: "ch_1", position: 940.0, duration: 1000.0)
        let finishedExact = try XCTUnwrap(store.progress(videoID: "vid_finished_exact"))
        XCTAssertTrue(finishedExact.finished)

        // Menos de 60 segundos restantes -> finished = true
        let itemLate = MediaItem(id: "vid_finished_late", title: "Late", channelTitle: "ch_1")
        try store.saveProgress(item: itemLate, channelID: "ch_1", position: 990.0, duration: 1000.0)
        let finishedLate = try XCTUnwrap(store.progress(videoID: "vid_finished_late"))
        XCTAssertTrue(finishedLate.finished)
    }

    func testLatestUnfinishedEpisodeProgress() throws {
        let store = makeStore()

        XCTAssertNil(store.latestUnfinishedEpisodeProgress())

        // Episodio no empezado (posición 0) no se considera pendiente
        let itemZero = MediaItem(id: "vid_zero", title: "Zero", channelTitle: "ch_1")
        try store.saveProgress(item: itemZero, channelID: "ch_1", position: 0.0, duration: 1800.0)
        XCTAssertNil(store.latestUnfinishedEpisodeProgress())

        // Episodio ya terminado no se considera pendiente
        let itemDone = MediaItem(id: "vid_done", title: "Done", channelTitle: "ch_1")
        try store.saveProgress(item: itemDone, channelID: "ch_1", position: 1750.0, duration: 1800.0)
        XCTAssertNil(store.latestUnfinishedEpisodeProgress())

        // Primer episodio a medio escuchar
        let itemFirst = MediaItem(id: "vid_first", title: "First", channelTitle: "ch_1")
        try store.saveProgress(item: itemFirst, channelID: "ch_1", position: 300.0, duration: 1800.0)
        let latestFirst = try XCTUnwrap(store.latestUnfinishedEpisodeProgress())
        XCTAssertEqual(latestFirst.videoID, "vid_first")
        XCTAssertEqual(latestFirst.title, "First")

        // Esperar brevemente o guardar segundo episodio para que updatedAt sea posterior
        let itemSecond = MediaItem(id: "vid_second", title: "Second", channelTitle: "ch_1")
        try store.saveProgress(item: itemSecond, channelID: "ch_1", position: 500.0, duration: 2400.0)
        let latestSecond = try XCTUnwrap(store.latestUnfinishedEpisodeProgress())
        XCTAssertEqual(latestSecond.videoID, "vid_second")
        XCTAssertEqual(latestSecond.title, "Second")

        // Si se termina el segundo episodio, el más reciente pasa a ser el primero
        try store.saveProgress(item: itemSecond, channelID: "ch_1", position: 2380.0, duration: 2400.0)
        let fallbackToFirst = try XCTUnwrap(store.latestUnfinishedEpisodeProgress())
        XCTAssertEqual(fallbackToFirst.videoID, "vid_first")
    }

    func testSeedDefaultShowsFollowsJREAndTWPOnce() throws {
        let store = makeStore()

        seedDefaultShowsIfNeeded(store: store)

        XCTAssertEqual(Set(store.followedShows().map(\.channelID)), ["UCzQUP1qoWDoEbmsQxvdjxgQ", "UCBYyJBCtCvgqA4NwtoPMwpQ"])

        // Dejar de seguir uno es definitivo: la siembra no vuelve a añadirlo
        try store.unfollow(channelID: "UCBYyJBCtCvgqA4NwtoPMwpQ")
        seedDefaultShowsIfNeeded(store: store)
        XCTAssertEqual(store.followedShows().map(\.channelID), ["UCzQUP1qoWDoEbmsQxvdjxgQ"])
    }

    func testBackendSyncWipeKeepsPodcastsAndProgress() throws {
        let store = makeStore()
        seedDefaultShowsIfNeeded(store: store)
        let episode = MediaItem(id: "vid_keep", title: "Ep", channelTitle: "JRE")
        try store.saveProgress(item: episode, channelID: "UCzQUP1qoWDoEbmsQxvdjxgQ", position: 600, duration: 7200)

        store.clearAllUserData(keepingPodcasts: true)

        XCTAssertEqual(store.followedShows().count, 2)
        XCTAssertEqual(store.progress(videoID: "vid_keep")?.position, 600)

        store.clearAllUserData()
        XCTAssertTrue(store.followedShows().isEmpty)
    }
}
