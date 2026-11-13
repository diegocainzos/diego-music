import XCTest
@testable import DiegoMusic

/// Deterministic SplitMix64 for reproducible seed sampling.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

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
        var rng = SeededGenerator(seed: 1)
        XCTAssertTrue(HomeLogic.distinctRecent([]).isEmpty)
        XCTAssertEqual(HomeLogic.quickPickSeeds([], using: &rng), [])
    }

    func testVariasSemillas() {
        let history = [track("A"), track("B"), track("A"), track("C"), track("D")]
        for seed in 0..<50 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let seeds = HomeLogic.quickPickSeeds(history, using: &rng)
            XCTAssertEqual(seeds.first, "A")
            XCTAssertEqual(seeds.count, 3)
            XCTAssertEqual(Set(seeds).count, seeds.count)
            XCTAssertTrue(seeds.allSatisfy { ["A", "B", "C", "D"].contains($0) })
        }
        let long = (0..<20).map { track("id\($0)") }
        let allowed = Set((0..<10).map { "id\($0)" })
        for seed in 0..<50 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let seeds = HomeLogic.quickPickSeeds(long, using: &rng)
            XCTAssertEqual(seeds.first, "id0")
            XCTAssertEqual(seeds.count, 3)
            XCTAssertTrue(seeds.allSatisfy { allowed.contains($0) }, "\(seeds)")
        }
    }

    func testConHistorialUnaPistaUnaSemilla() {
        var rng = SeededGenerator(seed: 3)
        XCTAssertEqual(HomeLogic.quickPickSeeds([track("A"), track("A")], using: &rng), ["A"])
    }

    func testVariasSemillasMezclaAlterna() {
        let merged = HomeLogic.mergeMixes(
            seeds: ["A", "B"],
            mixes: [[track("a1"), track("a2"), track("A")], [track("b1"), track("a1"), track("b2")]],
            limit: 20
        )
        XCTAssertEqual(merged.map(\.id), ["a1", "b1", "a2", "b2"])
    }

    func testVariasSemillasLimite() {
        func mix(_ p: String) -> [MediaItem] { (0..<30).map { track("\(p)\($0)") } }
        XCTAssertEqual(HomeLogic.mergeMixes(seeds: ["A", "B", "C"], mixes: [mix("a"), mix("b"), mix("c")]).count, 20)
        XCTAssertEqual(HomeLogic.mergeMixes(seeds: ["A"], mixes: [mix("a")], limit: 3).map(\.id), ["a0", "a1", "a2"])
    }

    func testConHistorialMixSinSemilla() {
        let merged = HomeLogic.mergeMixes(seeds: ["A"], mixes: [[track("A"), track("x"), track("y")]])
        XCTAssertEqual(merged.map(\.id), ["x", "y"])
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

@MainActor
final class HomeQuickPicksRefreshTests: XCTestCase {
    private func isolatedDefaults() -> UserDefaults {
        let name = "HomeQuickPicksRefreshTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testRefrescoLlenaSeleccionesConVariasSemillas() async {
        let a = track("AAAAAAAAAA1"), b = track("BBBBBBBBBB1")
        let service = AutoRadioStubService(results: [
            a.id: .success([track("a1"), track("a2"), a]),
            b.id: .success([track("b1"), track("a1"), track("b2")]),
        ])
        let model = HomeViewModel(service: service, defaults: isolatedDefaults())

        await model.refreshQuickPicks(history: [a, b, a])

        XCTAssertEqual(Set(service.calls), [a.id, b.id])
        XCTAssertEqual(model.quickPicks.map(\.id), ["a1", "b1", "a2", "b2"])
    }

    func testSinMixConservaListaPrevia() async {
        let a = track("AAAAAAAAAA1"), b = track("BBBBBBBBBB1")
        let service = AutoRadioStubService(results: [
            a.id: .success([a, track("x"), track("y")]),
            b.id: .failure(YouTubeServiceError.network),
        ])
        let model = HomeViewModel(service: service, defaults: isolatedDefaults())
        await model.refreshQuickPicks(history: [a])
        XCTAssertEqual(model.quickPicks.map(\.id), ["x", "y"])

        await model.refreshQuickPicks(history: [b])

        XCTAssertEqual(service.calls.last, b.id)
        XCTAssertEqual(model.quickPicks.map(\.id), ["x", "y"])
    }

    func testApareceAlInstanteDesdeListaGuardada() async {
        let a = track("AAAAAAAAAA1")
        let defaults = isolatedDefaults()
        let first = HomeViewModel(
            service: AutoRadioStubService(results: [a.id: .success([a, track("x"), track("y")])]),
            defaults: defaults
        )
        await first.refreshQuickPicks(history: [a])

        let relaunched = HomeViewModel(service: AutoRadioStubService(), defaults: defaults)
        XCTAssertEqual(relaunched.quickPicks.map(\.id), ["x", "y"])
    }
}
