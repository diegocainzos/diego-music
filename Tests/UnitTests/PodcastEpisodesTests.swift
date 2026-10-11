import XCTest
@testable import DiegoMusic

final class PodcastEpisodesTests: XCTestCase {
    func testISO8601DurationParser() {
        XCTAssertEqual(parseISO8601Duration("PT10M"), 600)
        XCTAssertEqual(parseISO8601Duration("PT3H"), 10800)
        XCTAssertEqual(parseISO8601Duration("PT40M"), 2400)
        XCTAssertEqual(parseISO8601Duration("PT39M59S"), 2399)
        XCTAssertEqual(parseISO8601Duration("PT1H2M3S"), 3723)
        XCTAssertEqual(parseISO8601Duration("PT45S"), 45)
        XCTAssertEqual(parseISO8601Duration("P1DT2H"), 93600)
        XCTAssertNil(parseISO8601Duration("invalid"))
        XCTAssertNil(parseISO8601Duration(""))
    }

    func testPodcastEpisodesFiltersUnder40MinutesAndCountsHidden() async throws {
        let transport = FakeYouTubeAPIEndpointTransport()
        let service = YouTubeDataService(
            configuration: APIConfiguration(youtubeDataKey: "test-key"),
            transport: transport
        )

        let result = try await service.podcastEpisodes(channelID: "UC_FILTER_TEST")

        // 1 de 3 h (10800 s >= 2400 s) y 1 de 10 min (600 s < 2400 s) -> 1 episodio, hiddenShortCount 1
        XCTAssertEqual(result.episodes.count, 1)
        XCTAssertEqual(result.hiddenShortCount, 1)

        let episode = try XCTUnwrap(result.episodes.first)
        XCTAssertEqual(episode.id, "vid_long")
        XCTAssertEqual(episode.title, "Episodio completo de 3 h")
        XCTAssertEqual(episode.durationSeconds, 10800)
        XCTAssertEqual(episode.thumbnailURL, URL(string: "https://example.com/episode.jpg"))
    }

    func testPodcastEpisodesCachesResultForOneHour() async throws {
        let transport = FakeYouTubeAPIEndpointTransport()
        let service = YouTubeDataService(
            configuration: APIConfiguration(youtubeDataKey: "test-key"),
            transport: transport
        )

        let first = try await service.podcastEpisodes(channelID: "UC_CACHE_TEST")
        let requestCountAfterFirst = await transport.requestCount

        let second = try await service.podcastEpisodes(channelID: "UC_CACHE_TEST")
        let requestCountAfterSecond = await transport.requestCount

        XCTAssertEqual(first, second)
        XCTAssertEqual(requestCountAfterFirst, requestCountAfterSecond, "La segunda llamada debió servirse de la caché")
    }

    func testPodcastEpisodesFollowsNextPageWhenFirstPageIsMostlyClips() async throws {
        let transport = FakeYouTubeAPIEndpointTransport(paged: true)
        let service = YouTubeDataService(
            configuration: APIConfiguration(youtubeDataKey: "test-key"),
            transport: transport
        )

        let result = try await service.podcastEpisodes(channelID: "UC_PAGED_TEST")

        XCTAssertEqual(result.episodes.map(\.id), ["vid_long", "vid_long2"])
        XCTAssertEqual(result.hiddenShortCount, 1)
        XCTAssertNil(result.nextPageToken)
    }

    func testPodcastEpisodesContinuesFromPageToken() async throws {
        let transport = FakeYouTubeAPIEndpointTransport(paged: true)
        let service = YouTubeDataService(
            configuration: APIConfiguration(youtubeDataKey: "test-key"),
            transport: transport
        )

        let result = try await service.podcastEpisodes(channelID: "UC_CONTINUE_TEST", pageToken: "P2")

        XCTAssertEqual(result.episodes.map(\.id), ["vid_long2"])
        XCTAssertNil(result.nextPageToken)
    }

    func testSearchChannelMapsChannelSnippet() async throws {
        let transport = FakeYouTubeAPIEndpointTransport()
        let service = YouTubeDataService(
            configuration: APIConfiguration(youtubeDataKey: "test-key"),
            transport: transport
        )

        let found = try await service.searchChannel("The Wild Project")
        let show = try XCTUnwrap(found)

        XCTAssertEqual(show.channelID, "UC_FOUND_CH")
        XCTAssertEqual(show.title, "Canal Encontrado")
        XCTAssertEqual(show.thumbnailURL, URL(string: "https://example.com/channel.jpg"))
    }
}

private actor FakeYouTubeAPIEndpointTransport: HTTPTransport {
    var requestCount: Int = 0
    let paged: Bool

    init(paged: Bool = false) {
        self.paged = paged
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        let urlString = request.url?.absoluteString ?? ""

        let json: String
        if paged, urlString.contains("/playlistItems"), urlString.contains("pageToken=P2") {
            json = #"""
            {
              "items": [
                {
                  "id": "item_long2",
                  "snippet": {
                    "publishedAt": "2023-12-01T10:00:00Z",
                    "title": "Episodio antiguo",
                    "channelId": "UC_TEST",
                    "channelTitle": "Canal Prueba",
                    "thumbnails": {},
                    "resourceId": { "videoId": "vid_long2" }
                  }
                }
              ]
            }
            """#
        } else if paged, urlString.contains("/videos"), urlString.contains("vid_long2") {
            json = #"""
            {
              "items": [
                {
                  "id": "vid_long2",
                  "snippet": {
                    "publishedAt": "2023-12-01T10:00:00Z",
                    "title": "Episodio antiguo",
                    "channelId": "UC_TEST",
                    "channelTitle": "Canal Prueba",
                    "thumbnails": {}
                  },
                  "contentDetails": { "duration": "PT1H" }
                }
              ]
            }
            """#
        } else if urlString.contains("/channels") {
            json = #"""
            {
              "items": [
                {
                  "id": "UC_TEST",
                  "contentDetails": {
                    "relatedPlaylists": {
                      "uploads": "UU_TEST_UPLOADS"
                    }
                  }
                }
              ]
            }
            """#
        } else if urlString.contains("/playlistItems") {
            json = #"""
            {
              "items": [
                {
                  "id": "item_short",
                  "snippet": {
                    "publishedAt": "2024-01-01T10:00:00Z",
                    "title": "Clip corto de 10 min",
                    "channelId": "UC_TEST",
                    "channelTitle": "Canal Prueba",
                    "thumbnails": {
                      "high": { "url": "https://example.com/clip.jpg" }
                    },
                    "resourceId": {
                      "videoId": "vid_short"
                    }
                  }
                },
                {
                  "id": "item_long",
                  "snippet": {
                    "publishedAt": "2024-01-02T10:00:00Z",
                    "title": "Episodio completo de 3 h",
                    "channelId": "UC_TEST",
                    "channelTitle": "Canal Prueba",
                    "thumbnails": {
                      "high": { "url": "https://example.com/episode.jpg" }
                    },
                    "resourceId": {
                      "videoId": "vid_long"
                    }
                  }
                }
              ]\#(paged ? #", "nextPageToken": "P2""# : "")
            }
            """#
        } else if urlString.contains("/videos") {
            json = #"""
            {
              "items": [
                {
                  "id": "vid_short",
                  "snippet": {
                    "publishedAt": "2024-01-01T10:00:00Z",
                    "title": "Clip corto de 10 min",
                    "channelId": "UC_TEST",
                    "channelTitle": "Canal Prueba",
                    "thumbnails": {}
                  },
                  "contentDetails": {
                    "duration": "PT10M"
                  }
                },
                {
                  "id": "vid_long",
                  "snippet": {
                    "publishedAt": "2024-01-02T10:00:00Z",
                    "title": "Episodio completo de 3 h",
                    "channelId": "UC_TEST",
                    "channelTitle": "Canal Prueba",
                    "thumbnails": {}
                  },
                  "contentDetails": {
                    "duration": "PT3H"
                  }
                }
              ]
            }
            """#
        } else if urlString.contains("/search") {
            json = #"""
            {
              "items": [
                {
                  "id": {
                    "kind": "youtube#channel",
                    "channelId": "UC_FOUND_CH"
                  },
                  "snippet": {
                    "publishedAt": "2024-01-01T00:00:00Z",
                    "title": "Canal Encontrado",
                    "description": "Descripción",
                    "channelId": "UC_FOUND_CH",
                    "channelTitle": "Canal Encontrado",
                    "thumbnails": {
                      "high": { "url": "https://example.com/channel.jpg" }
                    }
                  }
                }
              ]
            }
            """#
        } else {
            json = "{}"
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(json.utf8), response)
    }
}
