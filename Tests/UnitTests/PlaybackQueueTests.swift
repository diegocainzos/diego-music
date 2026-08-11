import XCTest
@testable import DiegoMusic

@MainActor
final class PlaybackQueueTests: XCTestCase {
    func testQueueNavigationAndRemovalStayConsistent() {
        let first = MediaItem(id: "1", title: "Uno", channelTitle: "A")
        let second = MediaItem(id: "2", title: "Dos", channelTitle: "B")
        let third = MediaItem(id: "3", title: "Tres", channelTitle: "C")
        let queue = PlaybackQueue()

        queue.play(first)
        queue.enqueue(second)
        queue.enqueue(third)
        XCTAssertEqual(queue.current, first)
        XCTAssertEqual(queue.advance(), second)

        queue.remove(id: second.id)
        XCTAssertEqual(queue.current, third)
        XCTAssertEqual(queue.retreat(), first)
    }

    func testCoordinatorPrefetchesNextQueueItem() async throws {
        let first = MediaItem(id: "AAAAAAAAAAA", title: "Uno", channelTitle: "A")
        let second = MediaItem(id: "BBBBBBBBBBB", title: "Dos", channelTitle: "B")
        let queue = PlaybackQueue(items: [first, second], currentIndex: 0)
        let resolver = RecordingAudioResolver()
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: resolver)

        coordinator.select(first)
        for _ in 0..<20 {
            if await resolver.resolvedVideoIDs().contains(second.id) { break }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        let resolved = await resolver.resolvedVideoIDs()
        XCTAssertEqual(resolved.first, first.id)
        XCTAssertTrue(resolved.contains(second.id))
        _ = coordinator
    }

    func testMovingItemsPreservesCurrentIdentity() {
        let items = (1...4).map { MediaItem(id: String($0), title: "Elemento \($0)", channelTitle: "Canal") }
        let queue = PlaybackQueue(items: items, currentIndex: 1)

        queue.move(from: IndexSet(integer: 0), to: 4)

        XCTAssertEqual(queue.current?.id, "2")
        XCTAssertEqual(queue.items.map(\.id), ["2", "3", "4", "1"])

        queue.move(id: "4", by: -1)
        XCTAssertEqual(queue.items.map(\.id), ["2", "4", "3", "1"])
        XCTAssertEqual(queue.current?.id, "2")
    }

    func testShufflePreservesCurrentTrackAndRestoresOrder() {
        let items = (1...5).map { MediaItem(id: String($0), title: "Pista \($0)", channelTitle: "Canal") }
        let queue = PlaybackQueue(items: items, currentIndex: 0)
        let originalOrder = queue.items.map(\.id)

        queue.setShuffle(true)
        XCTAssertTrue(queue.isShuffled)
        XCTAssertTrue(queue.current?.id == "1" || queue.current == items.first)

        // La pista activa se conserva dentro de la cola.
        XCTAssertEqual(queue.items.map(\.id).sorted(), originalOrder.sorted())

        queue.setShuffle(false)
        XCTAssertFalse(queue.isShuffled)
        XCTAssertEqual(queue.items.map(\.id), originalOrder)
        XCTAssertEqual(queue.current?.id, "1")
    }

    func testRepeatAllResetsToStart() {
        let first = MediaItem(id: "1", title: "Uno", channelTitle: "A")
        let second = MediaItem(id: "2", title: "Dos", channelTitle: "B")
        let queue = PlaybackQueue(items: [first, second], currentIndex: 1)

        XCTAssertEqual(queue.current?.id, "2")
        XCTAssertEqual(queue.resetToStart()?.id, "1")
        XCTAssertEqual(queue.currentIndex, 0)
    }
}

private actor RecordingAudioResolver: AudioStreamResolving {
    private var videoIDs: [String] = []

    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        videoIDs.append(videoID)
        return AudioStreamDescriptor(
            streamURL: URL(string: "https://audio.example.test/v1/audio/stream/\(videoID)")!,
            expiresAt: Date().addingTimeInterval(3_600),
            contentType: "audio/mp4"
        )
    }

    func invalidate(videoID: String) async {}

    func resolvedVideoIDs() -> [String] {
        videoIDs
    }
}
