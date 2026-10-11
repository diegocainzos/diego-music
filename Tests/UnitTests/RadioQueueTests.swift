import XCTest
@testable import DiegoMusic

@MainActor
final class RadioQueueTests: XCTestCase {
    func testSelectingAlbumTrackNeverAppendsExtraItems() async throws {
        let track1 = MediaItem(id: "AAAAAAAAAA1", title: "Pista 1", channelTitle: "Artista")
        let track2 = MediaItem(id: "AAAAAAAAAA2", title: "Pista 2", channelTitle: "Artista")
        let track3 = MediaItem(id: "AAAAAAAAAA3", title: "Pista 3", channelTitle: "Artista")
        let radioTrack = MediaItem(id: "RRRRRRRRRR1", title: "Radio 1", channelTitle: "Otro")

        let stubService = StubYouTubeDataService(radioResult: .success([radioTrack]))
        let queue = PlaybackQueue(items: [track1, track2, track3], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(
            queue: queue,
            resolver: TestRecordingAudioResolver(),
            youtubeService: stubService
        )

        coordinator.select(track1)
        try await Task.sleep(nanoseconds: 60_000_000)

        XCTAssertEqual(stubService.radioCalls.count, 0)
        XCTAssertEqual(queue.items.map(\.id), [track1.id, track2.id, track3.id])
        XCTAssertNil(coordinator.radioSeedTitle)
        _ = coordinator
    }

    func testStartRadioWithStubReplacesUpcoming() async throws {
        let track1 = MediaItem(id: "AAAAAAAAAA1", title: "Pista 1", channelTitle: "Artista")
        let track2 = MediaItem(id: "AAAAAAAAAA2", title: "Pista 2", channelTitle: "Artista")
        let track3 = MediaItem(id: "AAAAAAAAAA3", title: "Pista 3", channelTitle: "Artista")
        let radio1 = MediaItem(id: "RRRRRRRRRR1", title: "Radio 1", channelTitle: "Otro")
        let radio2 = MediaItem(id: "RRRRRRRRRR2", title: "Radio 2", channelTitle: "Otro")

        let stubService = StubYouTubeDataService(radioResult: .success([radio1, radio2]))
        let queue = PlaybackQueue(items: [track1, track2, track3], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(
            queue: queue,
            resolver: TestRecordingAudioResolver(),
            youtubeService: stubService
        )

        coordinator.startRadio()

        for _ in 0..<20 {
            if coordinator.radioSeedTitle != nil { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(coordinator.radioSeedTitle, track1.title)
        XCTAssertEqual(queue.items.map(\.id), [track1.id, radio1.id, radio2.id])
        XCTAssertEqual(queue.current, track1)
        XCTAssertEqual(queue.currentIndex, 0)
        XCTAssertNil(coordinator.errorMessage)

        // Detener radio restaura las pistas posteriores originales
        coordinator.stopRadio()
        XCTAssertNil(coordinator.radioSeedTitle)
        XCTAssertEqual(queue.items.map(\.id), [track1.id, track2.id, track3.id])
        XCTAssertEqual(queue.current, track1)
        XCTAssertEqual(queue.currentIndex, 0)
        _ = coordinator
    }

    func testStartRadioFailingLeavesQueueUnchanged() async throws {
        let track1 = MediaItem(id: "AAAAAAAAAA1", title: "Pista 1", channelTitle: "Artista")
        let track2 = MediaItem(id: "AAAAAAAAAA2", title: "Pista 2", channelTitle: "Artista")
        let track3 = MediaItem(id: "AAAAAAAAAA3", title: "Pista 3", channelTitle: "Artista")

        let stubService = StubYouTubeDataService(radioResult: .failure(YouTubeServiceError.network))
        let queue = PlaybackQueue(items: [track1, track2, track3], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(
            queue: queue,
            resolver: TestRecordingAudioResolver(),
            youtubeService: stubService
        )

        coordinator.startRadio()

        for _ in 0..<20 {
            if coordinator.errorMessage != nil { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(coordinator.errorMessage, "Radio no disponible para esta pista.")
        XCTAssertEqual(queue.items.map(\.id), [track1.id, track2.id, track3.id])
        XCTAssertNil(coordinator.radioSeedTitle)
        _ = coordinator
    }

    func testStartRadioEmptyLeavesQueueUnchanged() async throws {
        let track1 = MediaItem(id: "AAAAAAAAAA1", title: "Pista 1", channelTitle: "Artista")
        let track2 = MediaItem(id: "AAAAAAAAAA2", title: "Pista 2", channelTitle: "Artista")

        let stubService = StubYouTubeDataService(radioResult: .success([]))
        let queue = PlaybackQueue(items: [track1, track2], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(
            queue: queue,
            resolver: TestRecordingAudioResolver(),
            youtubeService: stubService
        )

        coordinator.startRadio()

        for _ in 0..<20 {
            if coordinator.errorMessage != nil { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(coordinator.errorMessage, "Radio no disponible para esta pista.")
        XCTAssertEqual(queue.items.map(\.id), [track1.id, track2.id])
        XCTAssertNil(coordinator.radioSeedTitle)
        _ = coordinator
    }

    func testSelectingDifferentItemClearsRadioState() async throws {
        let track1 = MediaItem(id: "AAAAAAAAAA1", title: "Pista 1", channelTitle: "Artista")
        let track2 = MediaItem(id: "AAAAAAAAAA2", title: "Pista 2", channelTitle: "Artista")
        let radio1 = MediaItem(id: "RRRRRRRRRR1", title: "Radio 1", channelTitle: "Otro")

        let stubService = StubYouTubeDataService(radioResult: .success([radio1]))
        let queue = PlaybackQueue(items: [track1, track2], currentIndex: 0)
        let coordinator = AudioPlayerCoordinator(
            queue: queue,
            resolver: TestRecordingAudioResolver(),
            youtubeService: stubService
        )

        coordinator.startRadio()

        for _ in 0..<20 {
            if coordinator.radioSeedTitle != nil { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(coordinator.radioSeedTitle, track1.title)

        coordinator.select(track2)
        XCTAssertNil(coordinator.radioSeedTitle)
        _ = coordinator
    }

    func testYouTubeDataServiceRadioValidatesSeedAndDecodesResponse() async throws {
        let resolverConfig = try AudioResolverConfiguration(baseURL: URL(string: "https://resolver.test")!, apiToken: String(repeating: "t", count: 40))
        let validJSON = """
        {
            "items": [
                {
                    "id": "bbbbbbbbbbb",
                    "title": "Canción Recomendada",
                    "channel": "Canal Radio",
                    "duration_seconds": 210
                }
            ]
        }
        """
        let transport = RadioStubHTTPTransport(statusCode: 200, data: Data(validJSON.utf8))
        let service = YouTubeDataService(
            configuration: nil,
            resolverConfiguration: resolverConfig,
            transport: transport
        )

        // ID inválido lanza invalidRequest
        do {
            _ = try await service.radio(seed: "corta")
            XCTFail("Se esperaba error por ID inválido")
        } catch {
            XCTAssertEqual(error as? YouTubeServiceError, .invalidRequest)
        }

        // ID válido de 11 caracteres decodifica elementos
        let items = try await service.radio(seed: "aaaaaaaaaaa")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "bbbbbbbbbbb")
        XCTAssertEqual(items.first?.title, "Canción Recomendada")
        XCTAssertEqual(items.first?.channelTitle, "Canal Radio")
        XCTAssertEqual(items.first?.durationSeconds, 210)
    }
}

private final class StubYouTubeDataService: YouTubeDataServicing, @unchecked Sendable {
    var radioResult: Result<[MediaItem], Error>
    private(set) var radioCalls: [String] = []

    init(radioResult: Result<[MediaItem], Error> = .success([])) {
        self.radioResult = radioResult
    }

    func search(query: String, pageToken: String?) async throws -> SearchPage {
        SearchPage(items: [], nextPageToken: nil)
    }

    func discover() async throws -> DiscoveryFeed {
        DiscoveryFeed(novedades: [], artistas: [])
    }

    func artist(byChannelID: String) async throws -> ArtistDetail {
        throw YouTubeServiceError.unavailable
    }

    func album(byPlaylistID: String) async throws -> Album {
        throw YouTubeServiceError.unavailable
    }

    func podcastEpisodes(channelID: String, pageToken: String?) async throws -> PodcastEpisodePage {
        PodcastEpisodePage(episodes: [], hiddenShortCount: 0)
    }

    func searchChannel(_ query: String) async throws -> PodcastShow? { nil }

    func radio(seed videoID: String) async throws -> [MediaItem] {
        radioCalls.append(videoID)
        return try radioResult.get()
    }
}

private actor TestRecordingAudioResolver: AudioStreamResolving {
    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        AudioStreamDescriptor(
            streamURL: URL(string: "https://audio.example.test/v1/audio/stream/\(videoID)")!,
            expiresAt: Date().addingTimeInterval(3_600),
            contentType: "audio/mp4"
        )
    }

    func invalidate(videoID: String) async {}
}

private struct RadioStubHTTPTransport: HTTPTransport {
    let statusCode: Int
    let data: Data

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}
