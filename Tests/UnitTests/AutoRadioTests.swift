import XCTest
@testable import DiegoMusic

/// Radio automática: `select(item, autoRadio: true)` arranca el Mix de la pista suelta.
@MainActor
final class AutoRadioTests: XCTestCase {
    private func track(_ id: String, _ title: String) -> MediaItem {
        MediaItem(id: id, title: title, channelTitle: "Artista")
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<40 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
    }

    func testPistaSueltaArrancaElMix() async throws {
        let a = track("AAAAAAAAAA1", "A"), b = track("BBBBBBBBBB1", "B"), c = track("CCCCCCCCCC1", "C")
        let m1 = track("MMMMMMMMMM1", "Mix 1"), m2 = track("MMMMMMMMMM2", "Mix 2")
        let service = AutoRadioStubService(results: [c.id: .success([m1, m2])])
        let queue = PlaybackQueue(items: [a, b], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: AutoRadioStubResolver(), youtubeService: service)

        coordinator.select(c, autoRadio: true)
        try await waitUntil { coordinator.radioSeedTitle != nil }

        XCTAssertEqual(queue.current, c)
        XCTAssertEqual(service.calls, [c.id])
        XCTAssertEqual(queue.items.map(\.id), [a.id, b.id, c.id, m1.id, m2.id])
        XCTAssertEqual(coordinator.radioSeedTitle, c.title)
        // AVPlayer falla con la URL ficticia; solo importa que no haya error de radio.
        XCTAssertNotEqual(coordinator.errorMessage, "Radio no disponible para esta pista.")
    }

    func testReproducirUnaListaNoArrancaLaRadio() async throws {
        let t1 = track("AAAAAAAAAA1", "1"), t2 = track("AAAAAAAAAA2", "2"), t3 = track("AAAAAAAAAA3", "3")
        let mix = track("MMMMMMMMMM1", "Mix")
        let service = AutoRadioStubService(results: [t1.id: .success([mix])])
        let queue = PlaybackQueue()
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: AutoRadioStubResolver(), youtubeService: service)

        // Igual que `AppEnvironment.playQueue`: sustituye la cola y selecciona sin radio.
        queue.replaceQueue(items: [t1, t2, t3], startIndex: 0)
        coordinator.select(t1)
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(service.calls, [])
        XCTAssertEqual(queue.items.map(\.id), [t1.id, t2.id, t3.id])
        XCTAssertEqual(queue.currentIndex, 0)
        XCTAssertNil(coordinator.radioSeedTitle)
    }

    func testMixNoDisponibleFallo() async throws {
        let a = track("AAAAAAAAAA1", "A"), c = track("CCCCCCCCCC1", "C"), b = track("BBBBBBBBBB1", "B")
        let service = AutoRadioStubService(results: [c.id: .failure(YouTubeServiceError.network)])
        let queue = PlaybackQueue(items: [a, c, b], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: AutoRadioStubResolver(), youtubeService: service)

        coordinator.select(c, autoRadio: true)
        try await waitUntil { service.calls.count == 1 }
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(service.calls, [c.id])
        XCTAssertEqual(queue.current, c)
        XCTAssertEqual(queue.items.map(\.id), [a.id, c.id, b.id])
        XCTAssertNil(coordinator.radioSeedTitle)
        // Radio silenciosa: sin mensaje de error de radio.
        XCTAssertNotEqual(coordinator.errorMessage, "Radio no disponible para esta pista.")
    }

    func testMixNoDisponibleVacio() async throws {
        let a = track("AAAAAAAAAA1", "A"), c = track("CCCCCCCCCC1", "C"), b = track("BBBBBBBBBB1", "B")
        let service = AutoRadioStubService(results: [c.id: .success([])])
        let queue = PlaybackQueue(items: [a, c, b], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: AutoRadioStubResolver(), youtubeService: service)

        coordinator.select(c, autoRadio: true)
        try await waitUntil { service.calls.count == 1 }
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(service.calls, [c.id])
        XCTAssertEqual(queue.current, c)
        XCTAssertEqual(queue.items.map(\.id), [a.id, c.id, b.id])
        XCTAssertNil(coordinator.radioSeedTitle)
        XCTAssertNotEqual(coordinator.errorMessage, "Radio no disponible para esta pista.")
    }

    func testRespuestaDelMixObsoleta() async throws {
        let a = track("AAAAAAAAAA1", "A"), c = track("CCCCCCCCCC1", "C"), d = track("DDDDDDDDDD1", "D")
        let mixC = track("XXXXXXXXXX1", "Mix C"), mixD = track("YYYYYYYYYY1", "Mix D")
        let service = AutoRadioStubService(
            results: [c.id: .success([mixC]), d.id: .success([mixD])],
            delays: [c.id: 400_000_000]
        )
        let queue = PlaybackQueue(items: [a], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: AutoRadioStubResolver(), youtubeService: service)

        coordinator.select(c, autoRadio: true)
        try await waitUntil { service.calls.count == 1 }
        coordinator.select(d, autoRadio: true)
        // Espera a que termine también la respuesta lenta de C.
        try await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(queue.current, d)
        let currentIndex = try XCTUnwrap(queue.currentIndex)
        XCTAssertEqual(Array(queue.items.dropFirst(currentIndex + 1)).map(\.id), [mixD.id])
        XCTAssertFalse(queue.items.contains(mixC))
        XCTAssertEqual(coordinator.radioSeedTitle, d.title)
    }

    func testPararLaRadio() async throws {
        let a = track("AAAAAAAAAA1", "A"), c = track("CCCCCCCCCC1", "C")
        let m1 = track("MMMMMMMMMM1", "Mix 1"), m2 = track("MMMMMMMMMM2", "Mix 2")
        let service = AutoRadioStubService(results: [c.id: .success([m1, m2])])
        let queue = PlaybackQueue(items: [a], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: AutoRadioStubResolver(), youtubeService: service)

        coordinator.select(c, autoRadio: true)
        try await waitUntil { coordinator.radioSeedTitle != nil }
        XCTAssertEqual(coordinator.radioSeedTitle, c.title)

        coordinator.stopRadio()

        XCTAssertNil(coordinator.radioSeedTitle)
        XCTAssertEqual(queue.current, c)
        XCTAssertEqual(queue.items.map(\.id), [a.id, c.id])
    }

    /// Flujo compuesto: pista suelta → Mix → la vista de cola lo muestra → tocar la 3.ª fila → otra pista suelta reemplaza el Mix.
    func testFlujoRadioVistaYSeleccion() async throws {
        let a = track("AAAAAAAAAA1", "A"), b = track("BBBBBBBBBB1", "B"), c = track("CCCCCCCCCC1", "C")
        let m1 = track("MMMMMMMMMM1", "Mix 1"), m2 = track("MMMMMMMMMM2", "Mix 2"), m3 = track("MMMMMMMMMM3", "Mix 3")
        let n1 = track("NNNNNNNNNN1", "Mix M2")
        let service = AutoRadioStubService(results: [c.id: .success([m1, m2, m3]), m2.id: .success([n1])])
        let queue = PlaybackQueue(items: [a, b], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: AutoRadioStubResolver(), youtubeService: service)

        coordinator.select(c, autoRadio: true)
        try await waitUntil { coordinator.radioSeedTitle != nil }

        let window = queue.upNextWindow()
        XCTAssertEqual(window.map { $0.item.id }, [c.id, m1.id, m2.id, m3.id])
        XCTAssertEqual(window.map { $0.index }, [2, 3, 4, 5])

        coordinator.selectFromQueue(at: window[2].index)
        XCTAssertEqual(queue.current, m2)
        XCTAssertEqual(queue.upNextWindow().map { $0.item.id }, [m2.id, m3.id])

        coordinator.select(m2, autoRadio: true)
        try await waitUntil { coordinator.radioSeedTitle == m2.title }
        XCTAssertEqual(coordinator.radioSeedTitle, m2.title)
        XCTAssertEqual(queue.upNextWindow().map { $0.item.id }, [m2.id, n1.id])
    }
}

/// Servicio de prueba con resultado y retraso por semilla. El retraso ignora la cancelación a propósito,
/// para que sea el coordinador quien descarte la respuesta obsoleta.
final class AutoRadioStubService: YouTubeDataServicing, @unchecked Sendable {
    private let lock = NSLock()
    private let results: [String: Result<[MediaItem], Error>]
    private let delays: [String: UInt64]
    private var recordedCalls: [String] = []

    init(results: [String: Result<[MediaItem], Error>] = [:], delays: [String: UInt64] = [:]) {
        self.results = results
        self.delays = delays
    }

    var calls: [String] { lock.withLock { recordedCalls } }

    func search(query: String, pageToken: String?) async throws -> SearchPage { SearchPage(items: [], nextPageToken: nil) }
    func discover() async throws -> DiscoveryFeed { DiscoveryFeed(novedades: [], artistas: []) }
    func artist(byChannelID: String) async throws -> ArtistDetail { throw YouTubeServiceError.unavailable }
    func album(byPlaylistID: String) async throws -> Album { throw YouTubeServiceError.unavailable }
    func podcastEpisodes(channelID: String, pageToken: String?) async throws -> PodcastEpisodePage {
        PodcastEpisodePage(episodes: [], hiddenShortCount: 0)
    }
    func searchChannel(_ query: String) async throws -> PodcastShow? { nil }

    func radio(seed videoID: String) async throws -> [MediaItem] {
        lock.withLock { recordedCalls.append(videoID) }
        if let delay = delays[videoID] {
            let deadline = DispatchTime.now().uptimeNanoseconds + delay
            while DispatchTime.now().uptimeNanoseconds < deadline {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        return try (results[videoID] ?? .success([])).get()
    }
}

actor AutoRadioStubResolver: AudioStreamResolving {
    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        AudioStreamDescriptor(
            streamURL: URL(string: "https://audio.example.test/v1/audio/stream/\(videoID)")!,
            expiresAt: Date().addingTimeInterval(3_600),
            contentType: "audio/mp4"
        )
    }

    func invalidate(videoID: String) async {}
}
