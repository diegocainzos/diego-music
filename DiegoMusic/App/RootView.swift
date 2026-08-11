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
        .tint(DiegoTheme.accent)
        .preferredColorScheme(environment.playbackSettings.themeMode.colorScheme)
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

                ZStack {
                    DiegoTheme.background.ignoresSafeArea()
                    destinationView(navState.current)
                }
            }
        }
    }

    // MARK: - Rama iPhone (Layout Jerárquico: Contenido Z-0, PlayerDock Z-1, PhoneTabBar Z-2)

    private var phoneTabView: some View {
        VStack(spacing: 0) {
            ZStack {
                DiegoTheme.background.ignoresSafeArea()
                destinationView(navState.current)
                    .id(navState.rootResetTrigger)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(0)

            PlayerDock(
                player: environment.player,
                queue: environment.queue
            )
            .zIndex(1)

            PhoneTabBar(navState: navState)
                .zIndex(2)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func themed<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            DiegoTheme.background.ignoresSafeArea()
            content()
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: AppDestination) -> some View {
        switch destination {
        case .home, .browse, .radio:
            HomeView { navState.navigate(to: .search) }
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
        case .songs:
            SongsView(library: environment.library, query: "", onPlay: environment.play)
        case .albums:
            AlbumsView(library: environment.library, query: "", onPlay: environment.play)
        case .artists:
            ArtistsView(library: environment.library, query: "", onPlay: environment.play)
        case .settings:
            SettingsView(
                playbackSettings: environment.playbackSettings,
                library: environment.library,
                resolverConfigured: environment.resolverConfigured
            )
        }
    }
}

// MARK: - Sidebar Component (Apple Music Web style)

struct SidebarView: View {
    @ObservedObject var navState: NavigationState
    @State private var sidebarSearchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Logo
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DiegoTheme.accent)
                        .frame(width: 30, height: 30)
                    Image(systemName: "music.note")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                }
                Text("Music")
                    .font(.title3.bold())
                    .foregroundStyle(DiegoTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Search Bar in Sidebar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(DiegoTheme.textSecondary)
                TextField("Search", text: $sidebarSearchText)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if !sidebarSearchText.isEmpty {
                            navState.navigate(to: .search)
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(DiegoTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Main Menu Section
                    VStack(alignment: .leading, spacing: 4) {
                        sidebarItem(.home, icon: "play.circle.fill", title: "Listen Now")
                        sidebarItem(.browse, icon: "grid", title: "Browse")
                        sidebarItem(.radio, icon: "radiowaves.left.and.right", title: "Radio")
                    }

                    // Library Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Library")
                            .font(.caption.bold())
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 2)

                        sidebarItem(.playlists, icon: "music.note.list", title: "Playlists")
                        sidebarItem(.songs, icon: "music.note", title: "Songs")
                        sidebarItem(.albums, icon: "square.stack", title: "Albums")
                        sidebarItem(.artists, icon: "music.mic", title: "Artists")
                    }

                    // Settings Section
                    VStack(alignment: .leading, spacing: 4) {
                        sidebarItem(.settings, icon: "gearshape", title: "Settings")
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }

    private func sidebarItem(_ destination: AppDestination, icon: String, title: String) -> some View {
        let isSelected = navState.current == destination
        return Button {
            navState.navigate(to: destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? .white : DiegoTheme.accent)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : DiegoTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? DiegoTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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

            // Sign In / Profile Accent Button
            Button {
                navState.navigate(to: .settings)
            } label: {
                Text("Sign In")
                    .font(.caption.bold())
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

// MARK: - Barra de Pestañas Inferior para iPhone (PhoneTabBar con z-index 2)

struct PhoneTabBar: View {
    @ObservedObject var navState: NavigationState

    private let mainTabs: [AppDestination] = [.home, .search, .library, .playlists, .settings]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(mainTabs) { destination in
                Button {
                    navState.selectTab(destination)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: destination.symbol)
                            .font(.system(size: 18, weight: navState.current == destination ? .bold : .regular))
                        Text(destination.title)
                            .font(.system(size: 10, weight: navState.current == destination ? .semibold : .medium))
                    }
                    .foregroundStyle(navState.current == destination ? DiegoTheme.accent : DiegoTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(destination.title)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 22)
        .background(DiegoTheme.surface)
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.12)
        }
    }
}
