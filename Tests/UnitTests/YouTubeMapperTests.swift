import XCTest
@testable import DiegoMusic

final class YouTubeMapperTests: XCTestCase {
    func testDecodingAndMappingOmitsNonVideoResults() throws {
        let data = Data(fixture.utf8)
        let decoded = try JSONDecoder.youtube.decode(YouTubeSearchResponseDTO.self, from: data)
        let page = YouTubeMapper().map(decoded)

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.id, "video-123")
        XCTAssertEqual(page.items.first?.title, "Rojo & Azul")
        XCTAssertEqual(page.items.first?.channelTitle, "Diego Música")
        XCTAssertEqual(page.nextPageToken, "NEXT")
    }

    private let fixture = #"""
    {
      "nextPageToken": "NEXT",
      "items": [
        {
          "id": { "kind": "youtube#video", "videoId": "video-123" },
          "snippet": {
            "publishedAt": "2024-01-02T03:04:05Z",
            "title": "Rojo &amp; Azul",
            "description": "",
            "channelId": "channel-1",
            "channelTitle": "Diego M&uacute;sica",
            "thumbnails": { "high": { "url": "https://example.com/image.jpg", "width": 480, "height": 360 } }
          }
        },
        {
          "id": { "kind": "youtube#channel", "channelId": "channel-2" },
          "snippet": {
            "title": "Canal",
            "channelTitle": "Canal",
            "thumbnails": {}
          }
        }
      ]
    }
    """#
}
