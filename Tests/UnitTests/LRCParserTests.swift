import XCTest
@testable import DiegoMusic

final class LRCParserTests: XCTestCase {

    // MARK: - Basic Format

    func testParseLRC_basicFormat() {
        let input = "[00:33.80] Look at the stars\n[00:36.23] Look how they shine for you"
        let result = LRCParser.parse(input)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].startTime ?? 0, 33.80, accuracy: 0.01)
        XCTAssertEqual(result[0].text, "Look at the stars")
        XCTAssertEqual(result[1].startTime ?? 0, 36.23, accuracy: 0.01)
        XCTAssertEqual(result[1].text, "Look how they shine for you")
    }

    func testParseLRC_endTimeCalculation() {
        let input = "[00:10.00] First line\n[00:20.00] Second line\n[00:30.00] Third line"
        let result = LRCParser.parse(input)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].endTime ?? 0, 20.0, accuracy: 0.01)
        XCTAssertEqual(result[1].endTime ?? 0, 30.0, accuracy: 0.01)
        XCTAssertNil(result[2].endTime) // Last line has no end time
    }

    func testParseLRC_millisecondFormat() {
        let input = "[01:23.456] Text with milliseconds"
        let result = LRCParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].startTime ?? 0, 83.456, accuracy: 0.001)
        XCTAssertEqual(result[0].text, "Text with milliseconds")
    }

    func testParseLRC_centisecondFormat() {
        let input = "[01:23.45] Text with centiseconds"
        let result = LRCParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].startTime ?? 0, 83.45, accuracy: 0.01)
    }

    func testParseLRC_emptyLines() {
        let input = "[00:10.00] Line one\n[00:15.00] \n[00:20.00] Line three"
        let result = LRCParser.parse(input)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result[1].text.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func testParseLRC_sortedByTime() {
        let input = "[00:30.00] Third\n[00:10.00] First\n[00:20.00] Second"
        let result = LRCParser.parse(input)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].text, "First")
        XCTAssertEqual(result[1].text, "Second")
        XCTAssertEqual(result[2].text, "Third")
    }

    func testParseLRC_emptyString() {
        let result = LRCParser.parse("")
        XCTAssertTrue(result.isEmpty)
    }

    func testParseLRC_invalidFormat() {
        let input = "This is just plain text\nNo timestamps here"
        let result = LRCParser.parse(input)
        XCTAssertTrue(result.isEmpty)
    }

    func testParseLRC_mixedValidInvalid() {
        let input = "Invalid line\n[00:10.00] Valid line\nAnother invalid"
        let result = LRCParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "Valid line")
    }

    func testParseLRC_zeroTimestamp() {
        let input = "[00:00.00] Very first line"
        let result = LRCParser.parse(input)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].startTime ?? -1, 0.0, accuracy: 0.01)
    }

    // MARK: - Track Metadata Extractor

    func testExtract_channelAsArtist() {
        let item = MediaItem(id: "test", title: "Yellow", channelTitle: "Coldplay")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Coldplay")
        XCTAssertEqual(track, "Yellow")
    }

    func testExtract_dashSeparated() {
        let item = MediaItem(id: "test", title: "Coldplay - Yellow", channelTitle: "ColdplayVEVO")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Coldplay")
        XCTAssertEqual(track, "Yellow")
    }

    func testExtract_officialVideo() {
        let item = MediaItem(id: "test", title: "Yellow (Official Video)", channelTitle: "Coldplay")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Coldplay")
        XCTAssertEqual(track, "Yellow")
    }

    func testExtract_officialMusicVideo() {
        let item = MediaItem(id: "test", title: "Levitating (Official Music Video)", channelTitle: "Dua Lipa")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Dua Lipa")
        XCTAssertEqual(track, "Levitating")
    }

    func testExtract_dashWithOfficialVideo() {
        let item = MediaItem(id: "test", title: "Coldplay - Yellow (Official Video)", channelTitle: "ColdplayVEVO")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Coldplay")
        XCTAssertEqual(track, "Yellow")
    }

    func testExtract_lyrics() {
        let item = MediaItem(id: "test", title: "Yellow (Lyrics)", channelTitle: "Coldplay")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Coldplay")
        XCTAssertEqual(track, "Yellow")
    }

    func testExtract_lyricVideo() {
        let item = MediaItem(id: "test", title: "Yellow (Lyric Video)", channelTitle: "Coldplay")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Coldplay")
        XCTAssertEqual(track, "Yellow")
    }

    func testExtract_cleanTitle() {
        let item = MediaItem(id: "test", title: "Blinding Lights", channelTitle: "The Weeknd")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "The Weeknd")
        XCTAssertEqual(track, "Blinding Lights")
    }

    func testExtract_topicChannel() {
        let item = MediaItem(id: "test", title: "Yellow", channelTitle: "Coldplay - Topic")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Coldplay")
        XCTAssertEqual(track, "Yellow")
    }

    func testExtract_vevoChannelWithCamelCase() {
        let item = MediaItem(id: "test", title: "Bad Romance (Official Music Video)", channelTitle: "LadyGagaVEVO")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Lady Gaga")
        XCTAssertEqual(track, "Bad Romance")
    }

    func testExtract_officialChannel() {
        let item = MediaItem(id: "test", title: "Bohemian Rhapsody (Official Video Remastered)", channelTitle: "Queen Official")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Queen")
        XCTAssertEqual(track, "Bohemian Rhapsody")
    }

    func testExtract_spanishVideoOficial() {
        let item = MediaItem(id: "test", title: "Tití Me Preguntó (Video Oficial)", channelTitle: "Bad Bunny")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Bad Bunny")
        XCTAssertEqual(track, "Tití Me Preguntó")
    }

    func testExtract_emDashAndEnDashSeparators() {
        let item = MediaItem(id: "test", title: "Bizarrap, Quevedo — Quevedo: Bzrp Music Sessions, Vol. 52", channelTitle: "Bizarrap")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Bizarrap, Quevedo")
        XCTAssertEqual(track, "Quevedo: Bzrp Music Sessions, Vol. 52")
    }

    func testExtract_bulletSeparator() {
        let item = MediaItem(id: "test", title: "The Weeknd • Blinding Lights (Official Audio)", channelTitle: "The Weeknd")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "The Weeknd")
        XCTAssertEqual(track, "Blinding Lights")
    }

    func testExtract_featInTitleAndParentheses() {
        let item = MediaItem(id: "test", title: "Dua Lipa - Levitating (feat. DaBaby) (Official Music Video)", channelTitle: "Dua Lipa")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Dua Lipa")
        XCTAssertEqual(track, "Levitating")
    }

    func testExtract_remasterAnd4KTags() {
        let item = MediaItem(id: "test", title: "Creep (Live at Reading 2009) [4K]", channelTitle: "Radiohead - Topic")
        let (artist, track) = TrackMetadataExtractor.extract(from: item)
        XCTAssertEqual(artist, "Radiohead")
        XCTAssertEqual(track, "Creep")
    }
}
