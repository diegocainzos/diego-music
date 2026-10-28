import XCTest
@testable import DiegoMusic

@MainActor
final class UpNextWindowTests: XCTestCase {
    private func list(_ count: Int) -> [MediaItem] {
        (1...count).map { MediaItem(id: String(format: "id%09d", $0), title: "T\($0)", channelTitle: "C") }
    }

    func testHistorialLargoMuestraDeLa25ALa30() {
        let items = list(30)
        let queue = PlaybackQueue(items: items, currentIndex: 24)
        let window = queue.upNextWindow()
        XCTAssertEqual(window.map { $0.index }, [24, 25, 26, 27, 28, 29])
        XCTAssertEqual(window[0].index, queue.currentIndex)
        XCTAssertEqual(window[0].item, items[24])
        XCTAssertEqual(window[5].item, items[29])
    }

    func testHistorialLargoComoMuchoActualY20Posteriores() {
        let queue = PlaybackQueue(items: list(30), currentIndex: 0)
        let window = queue.upNextWindow()
        XCTAssertEqual(window.count, 21)
        XCTAssertEqual(window[20].index, 20)
        XCTAssertEqual(queue.upNextWindow(limit: 5).count, 6)
    }

    func testSinPistaActualVistaVacia() {
        XCTAssertTrue(PlaybackQueue().upNextWindow().isEmpty)
    }

    func testLaRadioCambiaLaVista() {
        let current = MediaItem(id: "AAAAAAAAAA1", title: "A", channelTitle: "C")
        let mix = [MediaItem(id: "MMMMMMMMMM1", title: "M1", channelTitle: "C"),
                   MediaItem(id: "MMMMMMMMMM2", title: "M2", channelTitle: "C")]
        let queue = PlaybackQueue(items: [current], currentIndex: 0)
        XCTAssertEqual(queue.upNextWindow().map { $0.item.id }, [current.id])

        queue.replaceUpcoming(with: mix)

        let window = queue.upNextWindow()
        XCTAssertEqual(window.map { $0.item.id }, [current.id, mix[0].id, mix[1].id])
        XCTAssertEqual(window.map { $0.index }, [0, 1, 2])
    }

    func testSeleccionarDesdeLaVistaTerceraFila() {
        let items = list(10)
        let queue = PlaybackQueue(items: items, currentIndex: 3)
        let coordinator = AudioPlayerCoordinator(queue: queue, resolver: AutoRadioStubResolver())

        let row = queue.upNextWindow()[2]
        XCTAssertEqual(row.index, 5)
        XCTAssertEqual(row.item, items[5])

        coordinator.selectFromQueue(at: row.index)
        XCTAssertEqual(queue.current, items[5])
        XCTAssertEqual(queue.currentIndex, 5)
    }
}
