import SwiftUI

struct HomeView: View {
    let onStartSearch: () -> Void
    // Observa la biblioteca directamente: un ObservableObject anidado en AppEnvironment no redibuja la vista.
    @ObservedObject var library: LibraryStore
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var navState: NavigationState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var quickPicks: [MediaItem] = []
    @State private var genre: String?
    @State private var vibe: String?
    @State private var decade: String?
    @State private var country: String?
    @State private var discovery: DiscoveryState = .idle
    @State private var discoveryGeneration = 0

    private enum DiscoveryState {
        case idle, loading, empty, failed
        case loaded([MediaItem])
    }

    private var isCompact: Bool { sizeClass == .compact }

    init(library: LibraryStore, onStartSearch: @escaping () -> Void) {
        self.library = library
        self.onStartSearch = onStartSearch
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Cabecera superior Donda: "DIEGOMUSIC" centrado con tracking 6 y padding top 36
                Text("DIEGOMUSIC")
                    .dondaTitle(size: 14)
                    .tracking(6)
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 36)

                // 1. Sección "CONTINUAR" (si hay episodio a medias guardado)
                continueSection

                // 1b. Sección "SELECCIONES RÁPIDAS" (al azar de la biblioteca)
                quickPicksSection

                // 2. Sección "ESCUCHADO HACE POCO"
                recentlyPlayedSection

                // 3. Descubrimiento con filtros
                discoverySection

                // 4. Podcasts seguidos y favoritos
                followedPodcastsSection

                favoritesSection
            }
            .padding(.bottom, 40)
            .responsiveHorizontalPadding()
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(DiegoTheme.background.ignoresSafeArea())
        .onAppear(perform: shuffleQuickPicks)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { shuffleQuickPicks() }
        }
        .onChange(of: library.favorites.count) { _, _ in shuffleQuickPicks() }
    }

    /// Selecciones rápidas: 20 canciones al azar de la biblioteca.
    private func shuffleQuickPicks() {
        quickPicks = library.favorites.shuffled().prefix(20).map(\.mediaItem)
    }

    // MARK: - Cabecera de sección Donda

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .dondaLabel()
            .tracking(4)
            .foregroundStyle(DiegoTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1. Continuar episodio a medias

    @ViewBuilder
    private var continueSection: some View {
        if let progress = environment.library.latestUnfinishedEpisodeProgress() {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("CONTINUAR")

                HStack(alignment: .center, spacing: 14) {
                    AsyncImage(url: progress.thumbnailURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            DiegoTheme.background
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipped()
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(progress.channelTitle)
                            .dondaLabel()
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .lineLimit(1)

                        Text(progress.title)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text("QUEDAN \(formatRemaining(position: progress.position, duration: progress.duration))")
                            .dondaLabel()
                            .foregroundStyle(DiegoTheme.textSecondary)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(DiegoTheme.hairline)
                                    .frame(height: 1)
                                Rectangle()
                                    .fill(DiegoTheme.textPrimary)
                                    .frame(
                                        width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress.position / max(1, progress.duration)))),
                                        height: 1
                                    )
                            }
                        }
                        .frame(height: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        environment.playEpisode(progress.mediaItem, channelID: progress.channelID)
                    } label: {
                        Rectangle()
                            .fill(DiegoTheme.textPrimary)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(DiegoTheme.background)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reanudar \(progress.title)")
                }
                .padding(12)
                .background(DiegoTheme.background)
                .overlay(
                    Rectangle()
                        .stroke(DiegoTheme.outline, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    environment.playEpisode(progress.mediaItem, channelID: progress.channelID)
                }
            }
        }
    }

    // MARK: - 3. Tus podcasts seguidos

    @ViewBuilder
    private var followedPodcastsSection: some View {
        let shows = environment.library.followedShows()
        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("TUS PODCASTS")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(shows) { show in
                            Button {
                                navState.navigate(to: .podcastDetail(channelID: show.channelID, title: show.title))
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncImage(url: show.thumbnailURL) { phase in
                                        switch phase {
                                        case let .success(image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            DiegoTheme.background
                                        }
                                    }
                                    .frame(width: 128, height: 128)
                                    .clipped()
                                    .overlay(
                                        Rectangle()
                                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                                    )

                                    Text(show.title)
                                        .dondaLabel()
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(width: 128, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Podcast \(show.title)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Favoritos guardados

    @ViewBuilder
    private var favoritesSection: some View {
        let favorites = environment.library.favorites
        if !favorites.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("FAVORITOS")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(favorites.enumerated()), id: \.element.id) { index, track in
                            Button {
                                environment.play(track.mediaItem)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncImage(url: track.mediaItem.thumbnailURL) { phase in
                                        switch phase {
                                        case let .success(image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            DiegoTheme.background
                                        }
                                    }
                                    .frame(width: 128, height: 128)
                                    .clipped()
                                    .overlay(
                                        Rectangle()
                                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                                    )

                                    Text(track.title)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(1)

                                    Text(track.channelTitle)
                                        .dondaLabel()
                                        .foregroundStyle(DiegoTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 128, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reproducir \(track.title)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Selecciones rápidas y escuchado hace poco

    @ViewBuilder
    private var quickPicksSection: some View {
        if !quickPicks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("SELECCIONES RÁPIDAS")
                itemGrid(quickPicks)
            }
        }
    }

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        let recent = HomeLogic.distinctRecent(library.history.map(\.mediaItem))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("ESCUCHADO HACE POCO")
                itemGrid(recent)
            }
        }
    }

    private func playAllHeader(_ title: String, items: [MediaItem]) -> some View {
        HStack(alignment: .center, spacing: 12) {
            sectionHeader(title)
            outlineButton("REPRODUCIR TODO") {
                environment.playQueue(items, startingAt: 0)
            }
        }
    }

    private func outlineButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .dondaLabel()
                .foregroundStyle(DiegoTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    /// Fila compacta: carátula 48 pt, título semibold y artista.
    private func compactRow(_ item: MediaItem, width: CGFloat) -> some View {
        Button {
            environment.play(item)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                AsyncImage(url: item.thumbnailURL) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    default:
                        DiegoTheme.background
                    }
                }
                .frame(width: 48, height: 48)
                .clipped()
                .overlay(Rectangle().stroke(DiegoTheme.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .lineLimit(1)
                    Text(item.channelTitle)
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: width, height: 56, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reproducir \(item.title)")
    }

    /// Rejilla horizontal de 4 filas; columna ≈ 85% del ancho (máx. 360 pt).
    private func itemGrid(_ items: [MediaItem]) -> some View {
        GeometryReader { geo in
            let columnWidth = min(geo.size.width * 0.85, 360)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(56)), count: 4), spacing: 16) {
                    ForEach(items, id: \.id) { compactRow($0, width: columnWidth) }
                }
            }
        }
        .frame(height: 4 * 56 + 3 * 16)
    }

    // MARK: - Descubrimiento con filtros

    private var discoveryQuery: String? {
        HomeLogic.discoveryQuery(genre: genre, vibe: vibe, decade: decade, country: country)
    }

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DESCUBRIMIENTO")
            chipRow("GÉNERO", DiscoveryChips.genre, $genre)
            chipRow("VIBRA", DiscoveryChips.vibe, $vibe)
            chipRow("DÉCADA", DiscoveryChips.decade, $decade)
            chipRow("PAÍS", DiscoveryChips.country, $country)

            HStack {
                outlineButton("BUSCAR", disabled: discoveryQuery == nil) {
                    Task { await runDiscovery() }
                }
                Spacer()
            }

            switch discovery {
            case .idle:
                EmptyView()
            case .loading:
                Text("BUSCANDO").dondaLabel().foregroundStyle(DiegoTheme.textSecondary)
            case .empty:
                Text("SIN RESULTADOS").dondaLabel().foregroundStyle(DiegoTheme.textSecondary)
            case .failed:
                Text("No se pudo buscar.").dondaLabel().foregroundStyle(DiegoTheme.textSecondary)
            case let .loaded(items):
                playAllHeader("RESULTADOS", items: items)
                itemGrid(items)
            }
        }
    }

    private func chipRow(_ label: String, _ options: [String], _ selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).dondaLabel().foregroundStyle(DiegoTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let selected = selection.wrappedValue == option
                        Button {
                            selection.wrappedValue = selected ? nil : option
                        } label: {
                            Text(option.uppercased())
                                .dondaLabel()
                                .foregroundStyle(selected ? DiegoTheme.background : DiegoTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selected ? DiegoTheme.textPrimary : Color.clear)
                                .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func runDiscovery() async {
        guard let query = discoveryQuery else { return }
        discoveryGeneration += 1
        let generation = discoveryGeneration
        discovery = .loading
        do {
            let page = try await environment.youtubeService.search(query: query + " official", pageToken: nil)
            guard generation == discoveryGeneration else { return }
            let videos = Array(page.items.filter { $0.kind == .video && HomeLogic.looksLikeSong($0.title) }.prefix(20))
            discovery = videos.isEmpty ? .empty : .loaded(videos)
        } catch {
            guard generation == discoveryGeneration else { return }
            discovery = .failed
        }
    }

    private func formatRemaining(position: Double, duration: Double) -> String {
        let remaining = max(0, duration - position)
        let totalSeconds = Int(remaining)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours) H \(minutes) MIN"
        } else {
            return "\(max(1, minutes)) MIN"
        }
    }
}
