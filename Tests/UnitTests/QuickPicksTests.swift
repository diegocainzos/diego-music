import XCTest
@testable import DiegoMusic

@MainActor
final class QuickPicksTests: XCTestCase {
    private func track(_ id: String) -> MediaItem { MediaItem(id: id, title: "T\(id)", channelTitle: "C") }

    func testConHistorialListaElMixSinLaSemilla() async {
        let a = track("AAAAAAAAAA1"), x = track("XXXXXXXXXX1"), y = track("YYYYYYYYYY1")
        let service = AutoRadioStubService(results: [a.id: .success([a, x, y])])
        let model = HomeViewModel(service: service)

        await model.loadQuickPicks(seed: a)

        XCTAssertEqual(service.calls, [a.id])
        XCTAssertEqual(model.quickPicks.map(\.id), [x.id, y.id])
    }

    func testConHistorialComoMucho20() async {
        let a = track("AAAAAAAAAA1")
        let mix = (1...25).map { track(String(format: "M%010d", $0)) }
        let service = AutoRadioStubService(results: [a.id: .success([a] + mix)])
        let model = HomeViewModel(service: service)

        await model.loadQuickPicks(seed: a)

        XCTAssertEqual(model.quickPicks.map(\.id), mix.prefix(20).map(\.id))
    }

    func testSinHistorial() async {
        let service = AutoRadioStubService()
        let model = HomeViewModel(service: service)

        await model.loadQuickPicks(seed: nil)

        XCTAssertTrue(model.quickPicks.isEmpty)
        XCTAssertEqual(service.calls, [])
        if case .failed = model.state { XCTFail("No debe mostrarse error") }
    }

    func testSinMixPorFallo() async {
        let a = track("AAAAAAAAAA1")
        let service = AutoRadioStubService(results: [a.id: .failure(YouTubeServiceError.network)])
        let model = HomeViewModel(service: service)

        await model.loadQuickPicks(seed: a)

        XCTAssertTrue(model.quickPicks.isEmpty)
        if case .failed = model.state { XCTFail("No debe mostrarse error") }
    }

    func testSinMixPorListaVacia() async {
        let a = track("AAAAAAAAAA1")
        let service = AutoRadioStubService(results: [a.id: .success([])])
        let model = HomeViewModel(service: service)

        await model.loadQuickPicks(seed: a)

        XCTAssertTrue(model.quickPicks.isEmpty)
    }
}
