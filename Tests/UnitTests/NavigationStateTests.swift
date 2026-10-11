import XCTest
@testable import DiegoMusic

@MainActor
final class NavigationStateTests: XCTestCase {
    func testNavigationStateHistoryAndStackTransitions() {
        let navState = NavigationState(initialDestination: .home)
        XCTAssertEqual(navState.current, .home)
        XCTAssertFalse(navState.canGoBack)
        XCTAssertFalse(navState.canGoForward)

        navState.navigate(to: .search)
        XCTAssertEqual(navState.current, .search)
        XCTAssertTrue(navState.canGoBack)
        XCTAssertFalse(navState.canGoForward)
        XCTAssertEqual(navState.backStack, [.home])

        navState.navigate(to: .library)
        XCTAssertEqual(navState.current, .library)
        XCTAssertEqual(navState.backStack, [.home, .search])

        navState.goBack()
        XCTAssertEqual(navState.current, .search)
        XCTAssertTrue(navState.canGoBack)
        XCTAssertTrue(navState.canGoForward)
        XCTAssertEqual(navState.forwardStack, [.library])

        navState.goForward()
        XCTAssertEqual(navState.current, .library)
        XCTAssertFalse(navState.canGoForward)

        navState.navigate(to: .settings)
        XCTAssertTrue(navState.forwardStack.isEmpty)
        XCTAssertEqual(navState.current, .settings)
    }

    func testSelectTabResetsToRootWhenReTappingActiveTab() {
        let navState = NavigationState(initialDestination: .home)
        navState.navigate(to: .search)
        XCTAssertEqual(navState.current, .search)
        XCTAssertFalse(navState.backStack.isEmpty)

        // Re-tapping active tab (.search)
        let initialToken = navState.rootResetTrigger
        navState.selectTab(.search)
        XCTAssertEqual(navState.current, .search)
        XCTAssertTrue(navState.backStack.isEmpty)
        XCTAssertNotEqual(navState.rootResetTrigger, initialToken)
    }

    func testPodcastDetailDestination() {
        let destination = DiegoAppDestination.podcastDetail(channelID: "channel_123", title: "Test Podcast")
        XCTAssertEqual(destination.id, "podcast_channel_123")
        XCTAssertEqual(destination.title, "Test Podcast")
        XCTAssertEqual(destination.symbol, "mic")

        let navState = NavigationState(initialDestination: .home)
        navState.navigate(to: destination)
        XCTAssertEqual(navState.current, destination)
        XCTAssertEqual(navState.backStack, [.home])
    }

    func testDiegoAppDestinationsProperties() {
        XCTAssertEqual(DiegoAppDestination.home.title, "Inicio")
        XCTAssertEqual(DiegoAppDestination.search.title, "Buscar")
        XCTAssertEqual(DiegoAppDestination.library.title, "Biblioteca")
    }
}
