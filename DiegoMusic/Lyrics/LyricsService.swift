import Foundation

/// Contrato público de proveedor de letras sincronizadas.
///
/// Consume la pista activa (`MediaItem`) y devuelve los segmentos de letra
/// sincronizada. Queda desacoplado de la cola, del `AudioPlayerCoordinator` y
/// de la capa de YouTube para que `player-experience` (C1) pueda inyectar una
/// implementación en el reproductor ampliado sin reescribir esta capability.
///
/// La obtención de letras es **best-effort y opcional**: no scrapea letras con
/// derechos de autor. Si no hay letra disponible o el proveedor no está
/// configurado, devuelve `[]`/`nil` y la vista degrada con un estado vacío.
protocol LyricsProviding: Sendable {
    /// Devuelve los segmentos de letra para la pista dada, o `[]`/`nil` si no
    /// hay letra disponible. `currentTime` (segundos) se informa para permitir
    /// sincronización, aunque un proveedor puede ignorarlo al recuperar la
    /// letra completa.
    func lyrics(for item: MediaItem, at currentTime: Double) async -> [LyricSegment]?
}

/// Proveedor local/experimental por defecto.
///
/// No fabrica resultados sobre letras reales con copyright. Devuelve un
/// conjunto de ejemplos embebidos claramente etiquetados (o `nil`) únicamente
/// para probar la UI y el auto-scroll sin depender de una fuente de red.
/// Es sustituible por un proveedor legítimo futuro vía `LyricsProviding`.
struct LocalLyricsProvider: LyricsProviding {
    func lyrics(for item: MediaItem, at currentTime: Double) async -> [LyricSegment]? {
        // Demo: devuelve ejemplos solo para el vídeo reservado de prueba,
        // claramente etiquetados como experimentales y no reproducibles.
        guard item.id == Self.demoVideoID else { return [] }
        return [
            LyricSegment(lines: [
                LyricsLine(text: "(Letra de ejemplo experimental)", startTime: 0, endTime: 4),
                LyricsLine(text: "Sin derechos de autor", startTime: 4, endTime: 8),
                LyricsLine(text: "Solo para validar el auto-scroll", startTime: 8, endTime: 12),
            ])
        ]
    }

    private static let demoVideoID = "demo-lyrics"
}

/// Servicio de letras que combina un proveedor y expone el seam de integración.
struct LyricsService {
    let provider: any LyricsProviding

    init(provider: any LyricsProviding = LocalLyricsProvider()) {
        self.provider = provider
    }

    func lyrics(for item: MediaItem, at currentTime: Double) async -> [LyricSegment]? {
        await provider.lyrics(for: item, at: currentTime)
    }
}
