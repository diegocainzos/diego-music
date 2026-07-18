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
}
