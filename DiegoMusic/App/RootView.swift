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

/// Raíz de la app con navegación adaptativa por `horizontalSizeClass`:
/// - Compacto (iPhone): `TabView` con barra de pestañas inferior nativa.
/// - Regular (iPad/macOS): `NavigationSplitView` con el listado lateral.
/// En ambas ramas se comparte el `PlayerDock` como `safeAreaInset` inferior.
struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: AppDestination? = .home

    var body: some View {
        Group {
            if sizeClass == .compact {
                phoneTabView
            } else {
                splitView
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlayerDock(
                player: environment.player,
                queue: environment.queue
            )
        }
        .tint(DiegoTheme.accent)
    }

    // MARK: - Rama iPad/macOS (NavigationSplitView)

    private var splitView: some View {
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
    }

    // MARK: - Rama iPhone (TabView)

    private var phoneTabView: some View {
        TabView(selection: $selection) {
            themed { HomeView { selection = .search } }
                .tabItem { Label(AppDestination.home.title, systemImage: AppDestination.home.symbol) }
                .tag(AppDestination.home as AppDestination?)

            themed {
                SearchView(
                    service: environment.youtubeService,
                    library: environment.library,
                    onPlay: environment.play,
                    onFavorite: { try? environment.library.toggleFavorite($0) }
                )
            }
            .tabItem { Label(AppDestination.search.title, systemImage: AppDestination.search.symbol) }
            .tag(AppDestination.search as AppDestination?)

            themed { LibraryView(library: environment.library, onPlay: environment.play) }
                .tabItem { Label(AppDestination.library.title, systemImage: AppDestination.library.symbol) }
                .tag(AppDestination.library as AppDestination?)

            themed { PlaylistsView(library: environment.library, onPlay: environment.play) }
                .tabItem { Label(AppDestination.playlists.title, systemImage: AppDestination.playlists.symbol) }
                .tag(AppDestination.playlists as AppDestination?)

            themed {
                SettingsView(
                    playbackSettings: environment.playbackSettings,
                    library: environment.library,
                    resolverConfigured: environment.resolverConfigured
                )
            }
            .tabItem { Label(AppDestination.settings.title, systemImage: AppDestination.settings.symbol) }
            .tag(AppDestination.settings as AppDestination?)
        }
    }

    /// Envuelve el contenido de una pestaña en el fondo de la app para mantener
    /// la estética uniforme (fondo claro) dentro de la `TabView`.
    private func themed<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            DiegoTheme.background.ignoresSafeArea()
            content()
        }
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
                library: environment.library,
                resolverConfigured: environment.resolverConfigured
            )
        }
    }
}
