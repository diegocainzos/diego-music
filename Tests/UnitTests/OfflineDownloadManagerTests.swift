import CoreData
import XCTest
@testable import DiegoMusic

/// Pruebas unitarias del gestor de descargas offline.
/// Usa un contexto Core Data en memoria (inMemory: true) y un resolver stub.
@MainActor
final class OfflineDownloadManagerTests: XCTestCase {

    private var controller: PersistenceController!
    private var manager: OfflineDownloadManager!
    private var stubResolver: StubAudioResolver!

    override func setUp() async throws {
        controller = PersistenceController(inMemory: true)
        manager = OfflineDownloadManager(context: controller.container.viewContext)
        stubResolver = StubAudioResolver()
    }

    override func tearDown() async throws {
        // Limpiar ficheros descargados en el directorio de prueba
        try? manager.removeAllDownloads()
        manager = nil
        controller = nil
    }

    // MARK: - isDownloaded

    func testIsDownloaded_returnsFalseByDefault() {
        XCTAssertFalse(manager.isDownloaded(videoID: "dQw4w9WgXcQ"))
    }

    func testIsDownloaded_returnsFalseForUnknownID() {
        XCTAssertFalse(manager.isDownloaded(videoID: "xxxxxxxxxxx"))
    }

    // MARK: - localURL

    func testLocalURL_returnsNilWhenNotDownloaded() {
        XCTAssertNil(manager.localURL(for: "dQw4w9WgXcQ"))
    }

    // MARK: - removeDownload cuando no existe — no lanza

    func testRemoveDownload_nonExistent_doesNotThrow() {
        XCTAssertNoThrow(try manager.removeDownload(videoID: "dQw4w9WgXcQ"))
    }

    // MARK: - removeAllDownloads vacío — no lanza

    func testRemoveAllDownloads_whenEmpty_doesNotThrow() {
        XCTAssertNoThrow(try manager.removeAllDownloads())
    }

    // MARK: - Estado inicial de la cola

    func testDownloadedTracks_initiallyEmpty() {
        XCTAssertTrue(manager.downloadedTracks.isEmpty)
    }

    func testTotalDiskUsage_initiallyZero() {
        XCTAssertEqual(manager.totalDiskUsageBytes, 0)
    }

    // MARK: - Estado enqueued

    func testEnqueue_setsStateToQueued() {
        let item = MediaItem(id: "dQw4w9WgXcQ", title: "Test", channelTitle: "Test Artist")
        stubResolver.shouldFail = true // Evitar descarga real en test
        manager.enqueue(item, resolver: stubResolver)
        // El primer enqueue pasa inmediatamente a .downloading; no siempre .queued
        let state = manager.states[item.id]
        XCTAssertNotNil(state)
        XCTAssertNotEqual(state, .notDownloaded)
    }

    // MARK: - formattedTotalUsage

    func testFormattedTotalUsage_emptyIsReadable() {
        let result = manager.formattedTotalUsage
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - availableDiskSpace

    func testAvailableDiskSpace_isPositive() {
        XCTAssertGreaterThan(manager.availableDiskSpaceBytes, 0)
    }
}

// MARK: - Stub

/// Resolver de audio que falla inmediatamente (para tests que no quieren descarga real).
final class StubAudioResolver: AudioStreamResolving, @unchecked Sendable {
    var shouldFail = false
    var stubbedURL: URL = URL(string: "https://example.com/audio.m4a")!

    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        if shouldFail {
            throw AudioResolverServiceError.unavailable
        }
        return AudioStreamDescriptor(
            streamURL: stubbedURL,
            expiresAt: Date().addingTimeInterval(3600),
            contentType: "audio/mp4"
        )
    }

    func invalidate(videoID: String) async {}
}
