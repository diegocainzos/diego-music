import XCTest
@testable import DiegoMusic

@MainActor
final class EpisodePlaybackTests: XCTestCase {
    private static let persistence = PersistenceController(inMemory: true)

    private func makeStore() -> LibraryStore {
        let store = LibraryStore(context: Self.persistence.container.viewContext)
        store.clearAllUserData()
        return store
    }

    // MARK: - PlaybackSettings

    func testPlaybackSettingsRateCycleAndPersistence() throws {
        let store = makeStore()
        let settings = PlaybackSettings(libraryStore: store)

        // Valor por defecto: 1.0
        XCTAssertEqual(settings.podcastRate, 1.0)

        // Ciclo completo: 1.0 -> 1.25 -> 1.5 -> 1.75 -> 2.0 -> 1.0
        settings.cyclePodcastRate()
        XCTAssertEqual(settings.podcastRate, 1.25)
        XCTAssertEqual(store.preference(for: "playback.podcastRate"), "1.25")

        settings.cyclePodcastRate()
        XCTAssertEqual(settings.podcastRate, 1.5)
        XCTAssertEqual(store.preference(for: "playback.podcastRate"), "1.5")

        settings.cyclePodcastRate()
        XCTAssertEqual(settings.podcastRate, 1.75)
        XCTAssertEqual(store.preference(for: "playback.podcastRate"), "1.75")

        settings.cyclePodcastRate()
        XCTAssertEqual(settings.podcastRate, 2.0)
        XCTAssertEqual(store.preference(for: "playback.podcastRate"), "2.0")

        settings.cyclePodcastRate()
        XCTAssertEqual(settings.podcastRate, 1.0)
        XCTAssertEqual(store.preference(for: "playback.podcastRate"), "1.0")

        // Persistencia al recargar ajustes
        settings.cyclePodcastRate() // 1.25
        let reloaded = PlaybackSettings(libraryStore: store)
        XCTAssertEqual(reloaded.podcastRate, 1.25)
    }

    // MARK: - AudioPlayerCoordinator

    func testCoordinatorPlayEpisodeSetsPodcastContextAndSelectResetsToMusic() async throws {
        let episode = MediaItem(
            id: "ep_1",
            title: "Episodio 1",
            channelTitle: "Podcast Show",
            durationSeconds: 7200
        )
        let music = MediaItem(
            id: "song_1",
            title: "Canción 1",
            channelTitle: "Banda Musical",
            durationSeconds: 240
        )

        let queue = PlaybackQueue()
        let coordinator = AudioPlayerCoordinator(
            queue: queue,
            resolver: TestAudioResolver()
        )

        XCTAssertEqual(coordinator.context, .music)
        XCTAssertNil(coordinator.lastResumeSeconds)

        // Reproducir episodio con reanudación
        coordinator.playEpisode(episode, channelID: "ch_podcast", resumeAt: 450.0)

        XCTAssertEqual(coordinator.context, .podcast(channelID: "ch_podcast"))
        XCTAssertEqual(coordinator.lastResumeSeconds, 450.0)
        XCTAssertEqual(queue.items.map(\.id), [episode.id])
        XCTAssertEqual(queue.current?.id, episode.id)

        // Cambiar a música restablece contexto a .music y borra lastResumeSeconds
        coordinator.select(music)

        XCTAssertEqual(coordinator.context, .music)
        XCTAssertNil(coordinator.lastResumeSeconds)
        XCTAssertEqual(queue.current?.id, music.id)
    }

    func testCoordinatorPlayEpisodeWithoutResumeHasNilLastResumeSeconds() async throws {
        let episode = MediaItem(
            id: "ep_2",
            title: "Episodio 2",
            channelTitle: "Podcast Show",
            durationSeconds: 3600
        )

        let queue = PlaybackQueue()
        let coordinator = AudioPlayerCoordinator(
            queue: queue,
            resolver: TestAudioResolver()
        )

        coordinator.playEpisode(episode, channelID: "ch_podcast", resumeAt: 0)

        XCTAssertEqual(coordinator.context, .podcast(channelID: "ch_podcast"))
        XCTAssertNil(coordinator.lastResumeSeconds)
    }

    func testCoordinatorEpisodeProgressPersisterCalledOnContextChange() async throws {
        let episode = MediaItem(
            id: "ep_3",
            title: "Episodio 3",
            channelTitle: "Podcast Show",
            durationSeconds: 1800
        )
        let music = MediaItem(
            id: "song_3",
            title: "Canción 3",
            channelTitle: "Artista",
            durationSeconds: 180
        )

        let queue = PlaybackQueue()
        let coordinator = AudioPlayerCoordinator(
            queue: queue,
            resolver: TestAudioResolver()
        )

        var persistedItem: MediaItem?
        var persistedChannelID: String?
        coordinator.episodeProgressPersister = { item, channelID, _, _ in
            persistedItem = item
            persistedChannelID = channelID
        }

        coordinator.playEpisode(episode, channelID: "ch_show", resumeAt: 100)

        // Cambiar a música debe persistir el episodio anterior
        coordinator.select(music)

        XCTAssertEqual(persistedItem?.id, episode.id)
        XCTAssertEqual(persistedChannelID, "ch_show")
    }

    // MARK: - AppEnvironment

    func testAppEnvironmentPlayEpisodeResumesUnfinishedAndStartsFromBeginningIfFinished() throws {
        let store = makeStore()
        let env = AppEnvironment(modelContext: Self.persistence.container.viewContext)

        let episode = MediaItem(
            id: "ep_env_1",
            title: "Episodio Env",
            channelTitle: "Show Env",
            durationSeconds: 3600
        )

        // Sin progreso previo -> empieza en 0
        env.playEpisode(episode, channelID: "ch_env")
        XCTAssertEqual(env.player.context, .podcast(channelID: "ch_env"))
        XCTAssertNil(env.player.lastResumeSeconds)

        // Guardar progreso no terminado (posición 1200 / 3600)
        try store.saveProgress(item: episode, channelID: "ch_env", position: 1200.0, duration: 3600.0)
        env.playEpisode(episode, channelID: "ch_env")
        XCTAssertEqual(env.player.lastResumeSeconds, 1200.0)

        // Guardar progreso terminado (quedan 30 s)
        try store.saveProgress(item: episode, channelID: "ch_env", position: 3570.0, duration: 3600.0)
        env.playEpisode(episode, channelID: "ch_env")
        XCTAssertNil(env.player.lastResumeSeconds)
    }

    func testAppEnvironmentSynchronizesPodcastRateWithPlayer() throws {
        let env = AppEnvironment(modelContext: Self.persistence.container.viewContext)

        XCTAssertEqual(env.player.episodeRate, 1.0)

        env.playbackSettings.podcastRate = 1.5
        XCTAssertEqual(env.player.episodeRate, 1.5)

        env.playbackSettings.cyclePodcastRate()
        XCTAssertEqual(env.player.episodeRate, 1.75)
    }
}

private actor TestAudioResolver: AudioStreamResolving {
    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        AudioStreamDescriptor(
            streamURL: URL(string: "https://audio.example.test/v1/audio/stream/\(videoID)")!,
            expiresAt: Date().addingTimeInterval(3_600),
            contentType: "audio/mp4"
        )
    }

    func invalidate(videoID: String) async {}
}
