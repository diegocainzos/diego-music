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

    var accentColor: Color {
        DiegoTheme.accent
    }
}

typealias AppDestination = DiegoAppDestination

/// Estado de navegación con historial (Back < y Forward >) estilo Apple Music Web.
@MainActor
final class NavigationState: ObservableObject {
    @Published var current: AppDestination
    @Published private(set) var backStack: [AppDestination] = []
    @Published private(set) var forwardStack: [AppDestination] = []
    @Published var rootResetTrigger: UUID = UUID()

    init(initialDestination: AppDestination = .home) {
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

    func navigate(to destination: AppDestination) {
        guard destination != current else { return }
        backStack.append(current)
        current = destination
        forwardStack.removeAll()
    }

    /// Selecciona una pestaña; si ya es la pestaña activa, resetea la pila a la raíz.
    func selectTab(_ destination: AppDestination) {
        if current == destination {
            resetToRoot(destination)
        } else {
            navigate(to: destination)
        }
    }

    /// Resetea la pila de rutas e historial a la vista raíz de la pestaña actual.
    func resetToRoot(_ destination: AppDestination? = nil) {
        backStack.removeAll()
        forwardStack.removeAll()
        if let destination {
            current = destination
        }
        rootResetTrigger = UUID()
    }
}

/// Cabecera de navegación con botones `<` (Atrás) y `>` (Adelante) estilo Apple Music Web.
struct NavigationHeaderView: View {
    @ObservedObject var navigationState: NavigationState

    var body: some View {
        HStack(spacing: 8) {
            Button {
                navigationState.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(navigationState.canGoBack ? DiegoTheme.textPrimary : DiegoTheme.textSecondary.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .background(DiegoTheme.cardSurface)
                    .clipShape(Circle())
            }
            .disabled(!navigationState.canGoBack)
            .buttonStyle(.plain)
            .accessibilityLabel("Ir atrás")

            Button {
                navigationState.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(navigationState.canGoForward ? DiegoTheme.textPrimary : DiegoTheme.textSecondary.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .background(DiegoTheme.cardSurface)
                    .clipShape(Circle())
            }
            .disabled(!navigationState.canGoForward)
            .buttonStyle(.plain)
            .accessibilityLabel("Ir adelante")

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
