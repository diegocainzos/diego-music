import Combine
import CoreData
import Foundation

// MARK: - Tipos públicos

enum DownloadState: Equatable, Sendable {
    case notDownloaded
    case queued
    case downloading(progress: Double)
    case downloaded
    case failed(String)
}

struct DownloadProgressEvent: Sendable {
    let videoID: String
    let state: DownloadState
}

enum DownloadError: LocalizedError {
    case alreadyDownloaded
    case resolveFailure
    case writeFailed
    case quotaExceeded
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .alreadyDownloaded: return "La canción ya está descargada."
        case .resolveFailure: return "No se pudo obtener la pista de audio para descargar."
        case .writeFailed: return "Error al guardar el archivo en el dispositivo."
        case .quotaExceeded: return "Espacio insuficiente en el dispositivo."
        case .unknown: return "Error de descarga desconocido."
        }
    }
}

// MARK: - OfflineDownloadManager

/// Actor centralizado que gestiona las descargas offline de pistas de audio.
/// Usa Core Data para metadatos y el sandbox de la app para los ficheros de audio.
@MainActor
final class OfflineDownloadManager: ObservableObject {
    // Estado observable por videoID
    @Published private(set) var states: [String: DownloadState] = [:]
    @Published private(set) var downloadedTracks: [DownloadedTrack] = []
    @Published private(set) var totalDiskUsageBytes: Int64 = 0

    private let context: NSManagedObjectContext
    private var downloadQueue: [String] = []
    private var mediaItemMap: [String: MediaItem] = [:]
    private var activeDownloadTask: Task<Void, Never>?
    private var activeVideoID: String?
    private let maxRetries = 2

    init(context: NSManagedObjectContext) {
        self.context = context
        reload()
    }

    // MARK: - API pública

    func isDownloaded(videoID: String) -> Bool {
        states[videoID] == .downloaded
    }

    func localURL(for videoID: String) -> URL? {
        guard isDownloaded(videoID: videoID) else { return nil }
        guard let record = try? fetchRecord(videoID: videoID) else { return nil }
        return downloadsDirectory.appendingPathComponent(record.localFilePath)
    }

    /// Encola una sola pista para descargar.
    func enqueue(_ item: MediaItem, resolver: any AudioStreamResolving) {
        let id = item.id
        guard states[id] != .downloaded,
              states[id] != .queued
        else { return }
        if case .downloading = states[id] { return }
        states[id] = .queued
        mediaItemMap[id] = item
        if !downloadQueue.contains(id) {
            downloadQueue.append(id)
        }
        processNextInQueue(resolver: resolver)
    }

    /// Encola todas las pistas de una playlist/álbum.
    func enqueueBatch(_ items: [MediaItem], resolver: any AudioStreamResolving) {
        for item in items {
            let id = item.id
            guard states[id] != .downloaded,
                  states[id] != .queued
            else { continue }
            if case .downloading = states[id] { continue }
            states[id] = .queued
            mediaItemMap[id] = item
            if !downloadQueue.contains(id) {
                downloadQueue.append(id)
            }
        }
        processNextInQueue(resolver: resolver)
    }

    /// Elimina la descarga de una pista (fichero + Core Data).
    func removeDownload(videoID: String) throws {
        guard let record = try fetchRecord(videoID: videoID) else { return }
        let fileURL = downloadsDirectory.appendingPathComponent(record.localFilePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        context.delete(record)
        try context.save()
        reload()
    }

    /// Elimina todas las descargas.
    func removeAllDownloads() throws {
        let request = NSFetchRequest<DownloadedTrackRecord>(entityName: "DownloadedTrack")
        let records = try context.fetch(request)
        for record in records {
            let fileURL = downloadsDirectory.appendingPathComponent(record.localFilePath)
            try? FileManager.default.removeItem(at: fileURL)
            context.delete(record)
        }
        try context.save()
        reload()
    }

    // MARK: - Directorio de descargas

    private(set) lazy var downloadsDirectory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("DiegoMusic/Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Excluir del backup de iCloud
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var dirMutable = dir
        try? dirMutable.setResourceValues(resourceValues)
        return dir
    }()

    // MARK: - Privado: cola de descargas

    private func processNextInQueue(resolver: any AudioStreamResolving) {
        guard activeDownloadTask == nil || activeDownloadTask!.isCancelled else { return }
        guard !downloadQueue.isEmpty else { return }
        let videoID = downloadQueue.removeFirst()
        guard let item = mediaItemMap[videoID] else {
            processNextInQueue(resolver: resolver)
            return
        }
        activeVideoID = videoID
        activeDownloadTask = Task { [weak self] in
            await self?.performDownload(item: item, resolver: resolver, retryCount: 0)
        }
    }

    private func performDownload(
        item: MediaItem,
        resolver: any AudioStreamResolving,
        retryCount: Int
    ) async {
        let videoID = item.id
        states[videoID] = .downloading(progress: 0)

        do {
            // 1. Resolver URL opaca (expirable) desde el VPS
            let descriptor = try await resolver.resolve(videoID: videoID)

            // 2. Descargar datos con progreso
            let (tempURL, response) = try await downloadWithProgress(
                from: descriptor.streamURL,
                videoID: videoID
            )

            // 3. Determinar extensión y ruta final
            let ext = extensionFor(contentType: descriptor.contentType)
            let filename = "\(videoID).\(ext)"
            let destinationURL = downloadsDirectory.appendingPathComponent(filename)

            // Borrar si existía
            try? FileManager.default.removeItem(at: destinationURL)

            // 4. Mover atómicamente desde tmp
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            // 5. Obtener tamaño real
            let attrs = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let size = attrs[.size] as? Int64 ?? 0

            // 6. Guardar en Core Data
            try saveRecord(
                item: item,
                localFilePath: filename,
                fileSizeBytes: size,
                contentType: descriptor.contentType
            )

            // 7. Publicar estado final
            states[videoID] = .downloaded
            reload()

        } catch {
            if retryCount < maxRetries {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled {
                    await performDownload(item: item, resolver: resolver, retryCount: retryCount + 1)
                    return
                }
            }
            let message = sanitizedErrorMessage(error)
            states[videoID] = .failed(message)
        }

        // Siguiente en cola
        activeDownloadTask = nil
        activeVideoID = nil
        mediaItemMap.removeValue(forKey: videoID)
        processNextInQueue(resolver: resolver)
    }

    /// Descarga con seguimiento de progreso usando URLSession async delegate.
    private func downloadWithProgress(from url: URL, videoID: String) async throws -> (URL, URLResponse) {
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            throw DownloadError.resolveFailure
        }

        let expectedLength = Int(response.expectedContentLength)
        var receivedData = Data()
        if expectedLength > 0 { receivedData.reserveCapacity(expectedLength) }

        for try await byte in asyncBytes {
            receivedData.append(byte)
            if expectedLength > 0 {
                let progress = Double(receivedData.count) / Double(expectedLength)
                // Publicar en main actor
                let clampedProgress = min(progress, 1.0)
                if (receivedData.count % (256 * 1024)) == 0 {
                    await MainActor.run {
                        self.states[videoID] = .downloading(progress: clampedProgress)
                    }
                }
            }
        }

        // Escribir a fichero temporal
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(videoID)-\(UUID().uuidString).tmp")
        try receivedData.write(to: tempURL)
        return (tempURL, response)
    }

    // MARK: - Core Data helpers

    private func fetchRecord(videoID: String) throws -> DownloadedTrackRecord? {
        let request = NSFetchRequest<DownloadedTrackRecord>(entityName: "DownloadedTrack")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "videoID == %@", videoID)
        return try context.fetch(request).first
    }

    private func saveRecord(
        item: MediaItem,
        localFilePath: String,
        fileSizeBytes: Int64,
        contentType: String
    ) throws {
        // Upsert: borrar previo si existe
        if let existing = try fetchRecord(videoID: item.id) {
            context.delete(existing)
        }
        let record = NSEntityDescription.insertNewObject(
            forEntityName: "DownloadedTrack",
            into: context
        ) as! DownloadedTrackRecord
        record.videoID = item.id
        record.title = item.title
        record.channelTitle = item.channelTitle
        record.thumbnailURLString = item.thumbnailURL?.absoluteString
        record.localFilePath = localFilePath
        record.fileSizeBytes = fileSizeBytes
        record.downloadedAt = Date()
        record.contentType = contentType
        try context.save()
    }

    private func reload() {
        do {
            let request = NSFetchRequest<DownloadedTrackRecord>(entityName: "DownloadedTrack")
            request.sortDescriptors = [NSSortDescriptor(key: "downloadedAt", ascending: false)]
            let records = try context.fetch(request)
            downloadedTracks = records.map {
                DownloadedTrack(
                    videoID: $0.videoID,
                    title: $0.title,
                    channelTitle: $0.channelTitle,
                    thumbnailURLString: $0.thumbnailURLString,
                    localFilePath: $0.localFilePath,
                    fileSizeBytes: $0.fileSizeBytes,
                    downloadedAt: $0.downloadedAt,
                    contentType: $0.contentType
                )
            }
            totalDiskUsageBytes = records.reduce(0) { $0 + $1.fileSizeBytes }
            // Sincronizar estado: marcar como .downloaded los que existen en CD
            for track in downloadedTracks {
                if states[track.videoID] == nil || states[track.videoID] == .notDownloaded {
                    states[track.videoID] = .downloaded
                }
            }
        } catch {
            downloadedTracks = []
            totalDiskUsageBytes = 0
        }
    }

    // MARK: - Utilidades

    private func extensionFor(contentType: String) -> String {
        let lower = contentType.lowercased()
        if lower.contains("mp4") || lower.contains("m4a") { return "m4a" }
        if lower.contains("mpeg") || lower.contains("mp3") { return "mp3" }
        if lower.contains("ogg") { return "ogg" }
        if lower.contains("webm") { return "webm" }
        return "m4a"
    }

    private func sanitizedErrorMessage(_ error: Error) -> String {
        if let de = error as? DownloadError { return de.errorDescription ?? "Error de descarga." }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "Sin conexión. Inténtalo de nuevo cuando tengas red."
            case NSURLErrorTimedOut:
                return "La descarga tardó demasiado. Inténtalo de nuevo."
            default:
                return "Error de red al descargar."
            }
        }
        return "No se pudo completar la descarga."
    }

    // MARK: - Descarga en lote (batch coordinado internamente)

    /// Descarga una lista de ítems en serie, respetando el orden.
    func downloadBatch(_ items: [MediaItem], resolver: any AudioStreamResolving) {
        // Filtrar ya descargados
        let pending = items.filter { item in
            let s = states[item.id]
            if s == .downloaded { return false }
            if case .downloading = s { return false }
            if s == .queued { return false }
            return true
        }
        guard !pending.isEmpty else { return }
        for item in pending { states[item.id] = .queued }
        // Lanzar descarga serial en task
        activeDownloadTask?.cancel()
        activeDownloadTask = Task { [weak self] in
            guard let self else { return }
            for item in pending {
                guard !Task.isCancelled else { break }
                await self.performDownload(item: item, resolver: resolver, retryCount: 0)
            }
            await MainActor.run {
                self.activeDownloadTask = nil
            }
        }
    }

    var availableDiskSpaceBytes: Int64 {
        let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        )
        return attrs?[.systemFreeSize] as? Int64 ?? 0
    }

    var formattedTotalUsage: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalDiskUsageBytes)
    }
}
