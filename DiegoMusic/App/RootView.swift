import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case home
    case search
    case library
    case playlists
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Inicio"
        case .search: return "Búsqueda"
        case .library: return "Biblioteca"
        case .playlists: return "Playlists"
        case .settings: return "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "circle.grid.cross"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.3d.up"
        case .playlists: return "music.note.list"
        case .settings: return "slider.horizontal.3"
        }
    }

    var accentColor: Color {
        switch self {
        case .home: return DiegoTheme.accent
        case .search: return DiegoTheme.accent
        case .library: return DiegoTheme.accent
        case .playlists: return DiegoTheme.green
        case .settings: return DiegoTheme.accent
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selection: AppDestination? = .home

    var body: some View {
        NavigationSplitView {
            List(AppDestination.allCases, selection: $selection) { destination in
                HStack(spacing: 10) {
                    Image(systemName: destination.symbol).foregroundStyle(destination.accentColor)
                    Text(destination.title).foregroundStyle(DiegoTheme.textPrimary)
                }
                .font(.system(.body, design: .default, weight: .semibold))
                .tag(destination)
            }
            .navigationTitle("DiegoMusic")
            .scrollContentBackground(.hidden)
            .background(DiegoTheme.background)
        } detail: {
            ZStack {
                DiegoTheme.background.ignoresSafeArea()
                destinationView(selection ?? .home)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlayerDock(
                player: environment.player,
                queue: environment.queue
            )
        }
        .tint(DiegoTheme.accent)
    }

    @ViewBuilder
    private func destinationView(_ destination: AppDestination) -> some View {
        switch destination {
        case .home:
            HomeView { selection = .search }
        case .search:
            SearchView(
                service: environment.youtubeService,
                library: environment.library,
                onPlay: environment.play,
                onFavorite: { try? environment.library.toggleFavorite($0) }
            )
        case .library:
            LibraryView(library: environment.library, onPlay: environment.play)
        case .playlists:
            PlaylistsView(library: environment.library, onPlay: environment.play)
        case .settings:
            SettingsView(
                playbackSettings: environment.playbackSettings,
                resolverConfigured: environment.resolverConfigured
            )
        }
    }
}
