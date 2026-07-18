import XCTest
@testable import DiegoMusic

final class PlayerMessageTests: XCTestCase {
    func testValidStateMessageIsDecoded() {
        let body: [String: Any] = ["type": "state", "state": 1]
        XCTAssertEqual(PlayerMessageDecoder().decode(body: body), .stateChanged(.playing))
    }

    func testUnknownMessageIsIgnored() {
        XCTAssertNil(PlayerMessageDecoder().decode(body: ["type": "secret-event", "value": "ignored"]))
        XCTAssertNil(PlayerMessageDecoder().decode(body: "not-json-object"))
    }

    func testCommandEncodesOnlyExpectedFields() throws {
        let data = try JSONEncoder().encode(PlayerCommand.load(videoID: "safe-id"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(object, ["type": "load", "videoID": "safe-id"])
    }
}
