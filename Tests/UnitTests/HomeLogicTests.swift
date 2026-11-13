import XCTest
@testable import DiegoMusic

private func track(_ id: String) -> MediaItem { MediaItem(id: id, title: "T\(id)", channelTitle: "C") }

final class HomeLogicTests: XCTestCase {
    func testPistasRepetidas() {
        let history = [track("A"), track("B"), track("A"), track("C")]
        XCTAssertEqual(HomeLogic.distinctRecent(history).map(\.id), ["A", "B", "C"])
    }

    func testEscuchadoHacePocoMaximoDiez() {
        let history = (0..<15).map { track("id\($0)") }
        XCTAssertEqual(HomeLogic.distinctRecent(history).map(\.id), (0..<10).map { "id\($0)" })
    }

    func testSinHistorial() {
        XCTAssertTrue(HomeLogic.distinctRecent([]).isEmpty)
    }

    func testComponerLaBusqueda() {
        XCTAssertEqual(
            HomeLogic.discoveryQuery(genre: "Reggaetón", vibe: nil, decade: "2010s", country: "Colombia"),
            "reggaetón 2010s colombia"
        )
        XCTAssertEqual(HomeLogic.discoveryQuery(genre: nil, vibe: "Chill", decade: nil, country: nil), "chill")
    }

    func testNadaSeleccionado() {
        XCTAssertNil(HomeLogic.discoveryQuery(genre: nil, vibe: nil, decade: nil, country: nil))
    }

    func testChipsDeDescubrimiento() {
        XCTAssertEqual(DiscoveryChips.genre, ["Pop", "Rock", "Hip hop", "Reggaetón", "Reggae", "Electrónica", "House", "Techno", "Drum and bass", "Dubstep", "Trance", "Indie", "R&B", "Jazz", "Flamenco", "Clásica"])
        XCTAssertEqual(DiscoveryChips.vibe, ["Chill", "Fiesta", "Triste", "Energía", "Romántica", "Concentración"])
        XCTAssertEqual(DiscoveryChips.decade, ["70s", "80s", "90s", "2000s", "2010s", "2020s"])
        XCTAssertEqual(DiscoveryChips.country, ["España", "Galicia", "México", "Argentina", "Colombia", "USA", "UK", "Brasil", "Corea", "Japón", "Francia"])
    }
}

@MainActor
final class HomeHistoryStoreTests: XCTestCase {
    private static let persistence = PersistenceController(inMemory: true)

    func testRepeticionOReintentoNoAnadeEntrada() throws {
        let store = LibraryStore(context: Self.persistence.container.viewContext)
        try store.clearHistory()
        try store.addHistory(track("AAAAAAAAAA1"))
        try store.addHistory(track("AAAAAAAAAA1"))
        XCTAssertEqual(store.history.map(\.videoID), ["AAAAAAAAAA1"])

        try store.addHistory(track("BBBBBBBBBB1"))
        try store.addHistory(track("AAAAAAAAAA1"))
        XCTAssertEqual(store.history.count, 3)
        try store.clearHistory()
    }
}
