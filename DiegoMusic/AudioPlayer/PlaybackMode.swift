import Foundation

/// Modo de repetición de la cola de reproducción.
enum RepeatMode: Equatable, Sendable {
    case off
    case all
    case one
}

/// Proveedor best-effort de pistas relacionadas para autoplay/radio.
/// Inyectado de forma opcional; este cambio NO lo acopla al servicio de YouTube.
protocol RelatedTrackProviding: Sendable {
    func next(after current: MediaItem, playlist: [MediaItem]) async throws -> MediaItem?
}
