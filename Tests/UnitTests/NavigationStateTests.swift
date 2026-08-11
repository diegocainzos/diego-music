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
}
