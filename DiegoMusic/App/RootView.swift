import SwiftUI

/// Vista Raíz inspirada en Apple Music Web:
/// - Compacto (iPhone): `TabView` inferior nativa.
/// - Regular (iPad/macOS): `SidebarView` + `HeaderView` con historial + `DetailView`.
struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var navState = NavigationState()
    @State private var headerSearchText: String = ""

    var body: some View {
        Group {
            switch environment.authState {
            case .loading:
                ZStack {
                    DiegoTheme.background.ignoresSafeArea()
                    VStack(spacing: 16) {
                        AppleMusicLogoView(size: 48, showText: true)
                        ProgressView()
                            .tint(DiegoTheme.accent)
                    }
                }
            case .unauthenticated:
                AuthGateView()
            case .authenticated:
                if sizeClass == .compact {
                    phoneTabView
                } else {
                    desktopLayout
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            PlayerDock(
                                player: environment.player,
                                queue: environment.queue
                            )
                        }
                }
            }
        }
        .tint(DiegoTheme.accent)
        .preferredColorScheme(environment.playbackSettings.themeMode.colorScheme)
        .environmentObject(navState)
    }

    // MARK: - Rama Desktop / Regular (Apple Music Web Split Layout)

    private var desktopLayout: some View {
        HStack(spacing: 0) {
            SidebarView(navState: navState)
                .frame(width: 250)
                .background(DiegoTheme.surface)
                .overlay(
                    Rectangle()
                        .fill(DiegoTheme.textPrimary.opacity(0.08))
                        .frame(width: 1),
                    alignment: .trailing
                )

            VStack(spacing: 0) {
                HeaderView(
                    navState: navState,
                    searchText: $headerSearchText,
                    onSearchSubmit: {
                        if !headerSearchText.isEmpty {
                            navState.navigate(to: .search)
                        }
                    }
                )
                .frame(height: 56)
                .background(DiegoTheme.background)
                .overlay(
                    Rectangle()
                        .fill(DiegoTheme.textPrimary.opacity(0.06))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Banner de Sin Conexión
                OfflineBanner(monitor: environment.networkMonitor)
                    .animation(.easeInOut(duration: 0.3), value: environment.networkMonitor.isConnected)

                ZStack {
                    DiegoTheme.background.ignoresSafeArea()
                    destinationView(navState.current)
                }
            }
        }
    }

    // MARK: - Rama iPhone (Layout Jerárquico: Contenido con Mini-player flotante ZStack + PhoneTabBar)

    private var phoneTabView: some View {
        VStack(spacing: 0) {
            // Banner de Sin Conexión (parte superior en iPhone)
            OfflineBanner(monitor: environment.networkMonitor)
                .animation(.easeInOut(duration: 0.3), value: environment.networkMonitor.isConnected)

            ZStack(alignment: .bottom) {
                ZStack {
                    DiegoTheme.background.ignoresSafeArea()
                    destinationView(navState.current)
                        .id(navState.rootResetTrigger)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    if environment.queue.current != nil {
                        Color.clear.frame(height: 72)
                    }
                }

                if environment.queue.current != nil {
                    PlayerDock(
                        player: environment.player,
                        queue: environment.queue
                    )
                    .overlay(
                        Rectangle().stroke(DiegoTheme.outline, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PhoneTabBar(navState: navState)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private func destinationView(_ destination: DiegoAppDestination) -> some View {
        switch destination {
        case .home:
            HomeView { navState.navigate(to: .search) }
        case .search:
            SearchView(
                service: environment.youtubeService,
                library: environment.library,
                onPlay: environment.play,
                onFavorite: { try? environment.library.toggleFavorite($0) }
            )
        case .library:
            LibraryView(
                library: environment.library,
                onPlay: environment.play,
                onPlayQueue: environment.playQueue,
                youtubeService: environment.youtubeService,
                downloadManager: environment.downloadManager,
                resolver: environment.player.resolver,
                isOffline: !environment.networkMonitor.isConnected
            )
        case .playlists:
            PlaylistsView(
                library: environment.library,
                onPlay: environment.play,
                onPlayQueue: environment.playQueue,
                youtubeService: environment.youtubeService
            )
        case .songs:
            SongsView(
                library: environment.library,
                query: "",
                onPlay: environment.play,
                onPlayQueue: environment.playQueue,
                downloadManager: environment.downloadManager,
                resolver: environment.player.resolver,
                isOffline: !environment.networkMonitor.isConnected
            )
        case .albums:
            AlbumsView(library: environment.library, query: "", onPlay: environment.play)
        case .artists:
            ArtistsView(library: environment.library, query: "", onPlay: environment.play)
        case .settings:
            SettingsView(
                playbackSettings: environment.playbackSettings,
                library: environment.library,
                resolverConfigured: environment.resolverConfigured,
                downloadManager: environment.downloadManager
            )
        case let .artistDetail(id, name):
            ArtistView(
                artistID: id,
                artistTitle: name,
                service: environment.youtubeService,
                onPlay: environment.play
            )
        case let .albumDetail(id, title):
            AlbumView(
                playlistID: id,
                service: environment.youtubeService,
                onPlay: environment.play
            )
        case let .podcastDetail(channelID, title):
            PodcastDetailView(
                channelID: channelID,
                title: title
            )
        }
    }
}

// MARK: - Sidebar Component (Donda style)

struct SidebarView: View {
    @ObservedObject var navState: NavigationState

    private let items: [DiegoAppDestination] = [.home, .search, .library]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { destination in
                let isSelected = navState.current == destination
                Button {
                    navState.navigate(to: destination)
                } label: {
                    HStack {
                        Text(destination.title)
                            .dondaLabel()
                            .foregroundStyle(isSelected ? DiegoTheme.background : DiegoTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isSelected ? DiegoTheme.textPrimary : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(destination.title)
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 8)
    }
}

// MARK: - Header Component (Apple Music Web style with Back < and Forward >)

struct HeaderView: View {
    @ObservedObject var navState: NavigationState
    @Binding var searchText: String
    let onSearchSubmit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Navigation History Buttons (< >)
            HStack(spacing: 6) {
                Button {
                    navState.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(navState.canGoBack ? DiegoTheme.textPrimary : DiegoTheme.textSecondary.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(DiegoTheme.surface)
                        .clipShape(Circle())
                }
                .disabled(!navState.canGoBack)
                .buttonStyle(.plain)
                .accessibilityLabel("Go back")

                Button {
                    navState.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(navState.canGoForward ? DiegoTheme.textPrimary : DiegoTheme.textSecondary.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(DiegoTheme.surface)
                        .clipShape(Circle())
                }
                .disabled(!navState.canGoForward)
                .buttonStyle(.plain)
                .accessibilityLabel("Go forward")
            }

            Text(navState.current.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DiegoTheme.textPrimary)

            Spacer()

            // Header Search Input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(DiegoTheme.textSecondary)
                TextField("Search music...", text: $searchText)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .onSubmit(onSearchSubmit)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 220)
            .background(DiegoTheme.surface)
            .clipShape(Capsule())

            // Profile / Settings Button
            Button {
                navState.navigate(to: .settings)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle")
                        .font(.caption)
                    Text("Cuenta")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(DiegoTheme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Barra de Pestañas Inferior para iPhone (Donda)

struct PhoneTabBar: View {
    @ObservedObject var navState: NavigationState

    private let mainTabs: [DiegoAppDestination] = [.home, .search, .library]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(mainTabs) { destination in
                Button {
                    navState.selectTab(destination)
                } label: {
                    Text(destination.title)
                        .dondaLabel()
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(navState.current == destination ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(destination.title)
            }
        }
        .frame(height: 56)
        .background(DiegoTheme.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DiegoTheme.hairline)
                .frame(height: 1)
        }
    }
}
