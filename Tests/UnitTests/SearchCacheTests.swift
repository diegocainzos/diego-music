import XCTest
@testable import DiegoMusic

final class SearchCacheTests: XCTestCase {
    func testSearchCacheSetAndGet() async {
        let cache = SearchCache(ttl: 60)
        let item = MediaItem(id: "v123", title: "Yellow", channelTitle: "Coldplay")
        let page = SearchPage(items: [item], nextPageToken: nil)

        await cache.set(page, for: "Coldplay Yellow")

        let hit = await cache.get(for: "Coldplay Yellow")
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.items.first?.id, "v123")
    }

    func testSearchCacheNormalizesQuery() async {
        let cache = SearchCache(ttl: 60)
        let item = MediaItem(id: "v123", title: "Yellow", channelTitle: "Coldplay")
        let page = SearchPage(items: [item], nextPageToken: nil)

        await cache.set(page, for: "Coldplay - Yellow")

        // Diacritics, case, and extra spaces should hit cache
        let hit = await cache.get(for: "  COLDPLAY - yellow  ")
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.items.first?.id, "v123")
    }

    func testSearchCacheExpiration() async {
        // Immediate TTL expiration
        let cache = SearchCache(ttl: -1)
        let item = MediaItem(id: "v123", title: "Yellow", channelTitle: "Coldplay")
        let page = SearchPage(items: [item], nextPageToken: nil)

        await cache.set(page, for: "Coldplay Yellow")

        let miss = await cache.get(for: "Coldplay Yellow")
        XCTAssertNil(miss)
    }
}
