import Foundation

/// Contrato público de proveedor de letras sincronizadas.
///
/// Consume la pista activa (`MediaItem`) y devuelve los segmentos de letra
/// sincronizada. Queda desacoplado de la cola, del `AudioPlayerCoordinator` y
/// de la capa de YouTube para que `player-experience` (C1) pueda inyectar una
/// implementación en el reproductor ampliado sin reescribir esta capability.
protocol LyricsProviding: Sendable {
    /// Devuelve los segmentos de letra para la pista dada, o `[]`/`nil` si no
    /// hay letra disponible.
    func lyrics(for item: MediaItem, at currentTime: Double) async -> [LyricSegment]?
}

/// Servicio de letras que combina un proveedor LRCLIB y expone el resultado
/// completo (synced / plain / instrumental / notFound).
///
/// Mantiene retrocompatibilidad con `LyricsProviding` para la interfaz de
/// segmentos, y añade un método `fetchResult` que devuelve el `LyricsResult`
/// completo para que la UI pueda diferenciar entre letras sincronizadas,
/// texto plano, instrumental y no encontrado.
final class LyricsService: Sendable {
    private let lrcLibProvider: LRCLibLyricsProvider

    init(provider: LRCLibLyricsProvider = LRCLibLyricsProvider()) {
        self.lrcLibProvider = provider
    }

    /// Devuelve el resultado completo de letras para la pista.
    func fetchResult(for item: MediaItem) async -> LyricsResult {
        await lrcLibProvider.fetchLyrics(for: item)
    }

    /// Compatibilidad con la interfaz de segmentos.
    func lyrics(for item: MediaItem, at currentTime: Double) async -> [LyricSegment]? {
        await lrcLibProvider.lyrics(for: item, at: currentTime)
    }
}
