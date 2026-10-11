import XCTest
@testable import DiegoMusic

@MainActor
final class WarmTests: XCTestCase {
    func testWarmResolvesAtMostTwoAndSkipsCurrent() async throws {
        let fake = RecordingAudioResolver()
        let queue = PlaybackQueue()
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: fake)

        let items = [
            MediaItem(id: "TRACK_1", title: "Track 1", channelTitle: "Artist"),
            MediaItem(id: "TRACK_2", title: "Track 2", channelTitle: "Artist"),
            MediaItem(id: "TRACK_3", title: "Track 3", channelTitle: "Artist"),
            MediaItem(id: "TRACK_4", title: "Track 4", channelTitle: "Artist")
        ]

        coordinator.warm(items)

        for _ in 0..<50 {
            if await fake.recordedIDs.count >= 2 { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let recorded = await fake.recordedIDs
        XCTAssertEqual(recorded, [items[0].id, items[1].id])
        XCTAssertEqual(queue.items.count, 0)

        // Verifica que se omita la pista activa actual
        let currentItem = items[0]
        let queueWithCurrent = PlaybackQueue(items: [currentItem], currentIndex: 0)
        let fakeWithCurrent = RecordingAudioResolver()
        let coordinatorWithCurrent = AudioPlayerCoordinator(queue: queueWithCurrent, resolver: fakeWithCurrent)

        coordinatorWithCurrent.warm(items)

        for _ in 0..<50 {
            if await fakeWithCurrent.recordedIDs.count >= 2 { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let recordedWithCurrent = await fakeWithCurrent.recordedIDs
        XCTAssertEqual(recordedWithCurrent, [items[1].id, items[2].id])
        XCTAssertEqual(queueWithCurrent.items.count, 1)

        _ = coordinator
        _ = coordinatorWithCurrent
    }
}

private actor RecordingAudioResolver: AudioStreamResolving {
    private(set) var recordedIDs: [String] = []

    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        recordedIDs.append(videoID)
        return AudioStreamDescriptor(
            streamURL: URL(string: "https://audio.example.test/v1/audio/stream/\(videoID)")!,
            expiresAt: Date().addingTimeInterval(3_600),
            contentType: "audio/mp4"
        )
    }

    func invalidate(videoID: String) async {}
}
