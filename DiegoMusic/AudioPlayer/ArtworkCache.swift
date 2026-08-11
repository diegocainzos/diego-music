import CoreGraphics
import Foundation
import ImageIO

/// Caché pequeña en memoria de carátulas, compartida entre la interfaz del
/// reproductor y la publicación de Now Playing.
///
/// Actor aislado: todas las operaciones son seguras bajo concurrencia. El
/// valor se almacena como `CGImage` para que compile en iOS y macOS; el
/// consumidor lo envuelve en `UIImage`/`NSImage` según la plataforma.
actor ArtworkCache {
    static let shared = ArtworkCache()

    private let capacity: Int
    private var images: [URL: CGImage] = [:]
    private var order: [URL] = []

    init(capacity: Int = 32) {
        self.capacity = capacity
    }

    /// Devuelve la carátula para una URL, descargándola si no está en caché.
    /// Si la descarga falla o la URL no produce imagen, devuelve `nil`.
    @discardableResult
    func image(for url: URL) async -> CGImage? {
        if let existing = images[url] {
            touch(url)
            return existing
        }
        guard let image = await download(url) else { return nil }
        insert(url, image)
        return image
    }

    private func download(_ url: URL) async -> CGImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        } catch {
            return nil
        }
    }

    private func touch(_ url: URL) {
        if let index = order.firstIndex(of: url) {
            order.remove(at: index)
        }
        order.append(url)
    }

    private func insert(_ url: URL, _ image: CGImage) {
        images[url] = image
        touch(url)
        while order.count > capacity {
            let evicted = order.removeFirst()
            images.removeValue(forKey: evicted)
        }
    }
}
