import Foundation

/// Una línea de letra con marcas temporales opcionales (en segundos).
///
/// `startTime`/`endTime` son opcionales: una letra sin matriz de tiempo usa
/// `nil` en ambos y se representa sin auto-scroll.
struct LyricsLine: Identifiable, Equatable, Sendable {
    let text: String
    let startTime: Double?
    let endTime: Double?

    var id: String { "\(startTime ?? 0)-\(text)" }
}
