import Foundation

/// Ámbito de búsqueda: filtra en el cliente el mismo conjunto de resultados
/// devueltos por YouTube, sin lanzar peticiones adicionales.
enum SearchScope: String, CaseIterable, Identifiable {
    case todo
    case canciones
    case albumes
    case artistas
    case letras

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo: return "Todo"
        case .canciones: return "Canciones"
        case .albumes: return "Álbumes"
        case .artistas: return "Artistas"
        case .letras: return "Letras"
        }
    }

    var symbol: String {
        switch self {
        case .todo: return "square.grid.2x2"
        case .canciones: return "music.note"
        case .albumes: return "square.stack"
        case .artistas: return "person.crop.square"
        case .letras: return "text.quote"
        }
    }

    /// Indica si un resultado debe mostrarse bajo este ámbito.
    ///
    /// `letras` es una heurística visual best-effort por coincidencia de
    /// título/canal: DiegoMusic no dispone de índice de letras, así que NO se
    /// promete matching semántico del texto de la canción.
    func matches(_ item: MediaItem, query: String) -> Bool {
        switch self {
        case .todo:
            return true
        case .canciones:
            return item.kind == .video
        case .albumes:
            return item.kind == .playlist || item.kind == .video
        case .artistas:
            return item.kind == .channel
        case .letras:
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(q)
                || item.channelTitle.localizedCaseInsensitiveContains(q)
        }
    }
}
