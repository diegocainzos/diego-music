import Combine
import SwiftUI

enum DiegoAppDestination: Hashable, Identifiable {
    case home
    case browse
    case radio
    case search
    case library
    case playlists
    case songs
    case albums
    case artists
    case settings
    case artistDetail(id: String, name: String)
    case albumDetail(id: String, title: String)

    var id: String {
        switch self {
        case let .artistDetail(id, name): return "artist_\(id)_\(name)"
        case let .albumDetail(id, title): return "album_\(id)_\(title)"
        default: return String(describing: self)
        }
    }

    var title: String {
        switch self {
        case .home: return "Escuchar"
        case .browse: return "Explorar"
        case .radio: return "Radio"
        case .search: return "Buscar"
        case .library: return "Biblioteca"
        case .playlists: return "Playlists"
        case .songs: return "Canciones"
        case .albums: return "Álbumes"
        case .artists: return "Artistas"
        case .settings: return "Ajustes"
        case let .artistDetail(_, name): return name
        case let .albumDetail(_, title): return title
        }
    }

    var symbol: String {
        switch self {
        case .home: return "play.circle.fill"
        case .browse: return "grid"
        case .radio: return "radiowaves.left.and.right"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.3d.up"
        case .playlists: return "music.note.list"
        case .songs: return "music.note"
        case .albums, .albumDetail: return "square.stack"
        case .artists, .artistDetail: return "music.mic"
        case .settings: return "gearshape"
        }
    }
}

/// Estado de navegación con historial (Back < y Forward >) estilo Apple Music Web.
@MainActor
final class NavigationState: ObservableObject {
    @Published var current: DiegoAppDestination
    @Published private(set) var backStack: [DiegoAppDestination] = []
    @Published private(set) var forwardStack: [DiegoAppDestination] = []
    @Published var rootResetTrigger: UUID = UUID()

    init(initialDestination: DiegoAppDestination = .home) {
        self.current = initialDestination
    }

    var canGoBack: Bool {
        !backStack.isEmpty
    }

    var canGoForward: Bool {
        !forwardStack.isEmpty
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(current)
        current = previous
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(current)
        current = next
    }

    func navigate(to destination: DiegoAppDestination) {
        guard destination != current else { return }
        backStack.append(current)
        current = destination
        forwardStack.removeAll()
    }

    /// Selecciona una pestaña; si ya es la pestaña activa, resetea la pila a la raíz.
    func selectTab(_ destination: DiegoAppDestination) {
        if current == destination {
            resetToRoot(destination)
        } else {
            navigate(to: destination)
        }
    }

    /// Resetea la pila de rutas e historial a la vista raíz de la pestaña actual.
    func resetToRoot(_ destination: DiegoAppDestination? = nil) {
        backStack.removeAll()
        forwardStack.removeAll()
        if let destination {
            current = destination
        }
        rootResetTrigger = UUID()
    }
}
