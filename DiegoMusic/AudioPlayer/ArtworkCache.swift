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

    private let images: NSCache<NSURL, CGImage> = {
        let cache = NSCache<NSURL, CGImage>()
        cache.countLimit = 32
        return cache
    }()

    /// Devuelve la carátula para una URL, descargándola si no está en caché.
    /// Si la descarga falla o la URL no produce imagen, devuelve `nil`.
    @discardableResult
    func image(for url: URL) async -> CGImage? {
        let key = url as NSURL
        if let existing = images.object(forKey: key) { return existing }
        guard let image = await download(url) else { return nil }
        images.setObject(image, forKey: key)
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
}
