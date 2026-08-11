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

/// Un segmento de letra (p. ej. una estrofa o el estribillo) formado por una
/// o más `LyricsLine`. Permite agrupar versos manteniendo el orden de las
/// líneas dentro de cada segmento.
struct LyricSegment: Identifiable, Equatable, Sendable {
    let lines: [LyricsLine]

    var id: String { lines.map(\.id).joined(separator: "|") }
}
