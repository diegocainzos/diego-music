import XCTest
@testable import DiegoMusic

final class APIConfigurationTests: XCTestCase {
    func testSingleKeyParsing() {
        let config = APIConfiguration(youtubeDataKey: "KEY_ONE")
        XCTAssertEqual(config.youtubeDataKeys, ["KEY_ONE"])
        XCTAssertEqual(config.primaryKey, "KEY_ONE")
    }

    func testMultipleCommaSeparatedKeysParsing() {
        let config = APIConfiguration(youtubeDataKey: "KEY_ONE, KEY_TWO,KEY_THREE ")
        XCTAssertEqual(config.youtubeDataKeys, ["KEY_ONE", "KEY_TWO", "KEY_THREE"])
        XCTAssertEqual(config.primaryKey, "KEY_ONE")
    }

    func testKeyPoolRotation() async {
        let pool = KeyPool(keys: ["KEY_A", "KEY_B"])
        let count = await pool.keyCount
        XCTAssertEqual(count, 2)

        let initialKey = await pool.currentKey()
        XCTAssertEqual(initialKey, "KEY_A")

        let nextKey = await pool.rotateToNextKey()
        XCTAssertEqual(nextKey, "KEY_B")

        let currentAfterRotate = await pool.currentKey()
        XCTAssertEqual(currentAfterRotate, "KEY_B")

        let cycledKey = await pool.rotateToNextKey()
        XCTAssertEqual(cycledKey, "KEY_A")
    }
}
