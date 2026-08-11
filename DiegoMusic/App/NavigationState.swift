import Combine
import SwiftUI

enum DiegoAppDestination: String, CaseIterable, Identifiable {
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

    var id: String { rawValue }

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
        case .albums: return "square.stack"
        case .artists: return "music.mic"
        case .settings: return "gearshape"
        }
    }

    var accentColor: Color {
        switch self {
        case .home, .browse, .radio, .search, .library, .songs, .albums, .artists, .settings, .playlists:
            return DiegoTheme.accent
        }
    }
}

typealias AppDestination = DiegoAppDestination

/// Estado de navegación con historial (Back < y Forward >) estilo Apple Music Web.
@MainActor
final class NavigationState: ObservableObject {
    @Published var current: AppDestination
    @Published private(set) var backStack: [AppDestination] = []
    @Published private(set) var forwardStack: [AppDestination] = []

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
