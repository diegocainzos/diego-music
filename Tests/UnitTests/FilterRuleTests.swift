import XCTest
@testable import DiegoMusic

final class FilterRuleTests: XCTestCase {
    func testRuleSchemaUsesWebKitCodingKeys() throws {
        let rule = ContentBlockerRule(
            trigger: .init(
                urlFilter: ".*diegomusic-ad-test.*",
                resourceType: ["image"],
                ifDomain: nil,
                unlessDomain: ["music.youtube.com"]
            ),
            action: .init(type: "block")
        )
        let data = try JSONEncoder().encode([rule])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let trigger = try XCTUnwrap(json.first?["trigger"] as? [String: Any])

        XCTAssertEqual(trigger["url-filter"] as? String, ".*diegomusic-ad-test.*")
        XCTAssertEqual(trigger["resource-type"] as? [String], ["image"])
        XCTAssertEqual(trigger["unless-domain"] as? [String], ["music.youtube.com"])
    }

    func testInvalidCustomListIsRejected() {
        let loader = FilterListLoader()
        XCTAssertThrowsError(try loader.validateCustomList(Data("{}".utf8)))
        XCTAssertThrowsError(try loader.validateCustomList(Data("[]".utf8)))
    }
}
