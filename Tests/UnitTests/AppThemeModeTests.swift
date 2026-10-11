import XCTest
@testable import DiegoMusic

final class AppThemeModeTests: XCTestCase {
    func testAppThemeModeMigrating() {
        XCTAssertEqual(AppThemeMode.migrating("midnight"), .black)
        XCTAssertEqual(AppThemeMode.migrating("dark"), .black)
        XCTAssertEqual(AppThemeMode.migrating("system"), .black)
        XCTAssertEqual(AppThemeMode.migrating(nil), .black)
        XCTAssertEqual(AppThemeMode.migrating("light"), .white)
        XCTAssertEqual(AppThemeMode.migrating("white"), .white)
        XCTAssertEqual(AppThemeMode.migrating("black"), .black)
        XCTAssertEqual(AppThemeMode.migrating("x"), .black)
    }

    func testAppThemeModeProperties() {
        XCTAssertEqual(AppThemeMode.black.title, "Negro")
        XCTAssertEqual(AppThemeMode.white.title, "Blanco")
        XCTAssertEqual(AppThemeMode.black.icon, "circle.fill")
        XCTAssertEqual(AppThemeMode.white.icon, "circle")
        XCTAssertEqual(AppThemeMode.black.colorScheme, .dark)
        XCTAssertEqual(AppThemeMode.white.colorScheme, .light)
        XCTAssertEqual(AppThemeMode.allCases, [.black, .white])
    }

    func testAppThemeModeCodableDecoding() throws {
        let decoder = JSONDecoder()

        let legacyMidnight = try decoder.decode(AppThemeMode.self, from: Data("\"midnight\"".utf8))
        XCTAssertEqual(legacyMidnight, .black)

        let legacyDark = try decoder.decode(AppThemeMode.self, from: Data("\"dark\"".utf8))
        XCTAssertEqual(legacyDark, .black)

        let legacySystem = try decoder.decode(AppThemeMode.self, from: Data("\"system\"".utf8))
        XCTAssertEqual(legacySystem, .black)

        let legacyLight = try decoder.decode(AppThemeMode.self, from: Data("\"light\"".utf8))
        XCTAssertEqual(legacyLight, .white)

        let standardWhite = try decoder.decode(AppThemeMode.self, from: Data("\"white\"".utf8))
        XCTAssertEqual(standardWhite, .white)

        let standardBlack = try decoder.decode(AppThemeMode.self, from: Data("\"black\"".utf8))
        XCTAssertEqual(standardBlack, .black)

        let unknown = try decoder.decode(AppThemeMode.self, from: Data("\"random_unknown\"".utf8))
        XCTAssertEqual(unknown, .black)
    }
}
