import SwiftUI

struct HomeView: View {
    let onStartSearch: () -> Void
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var navState: NavigationState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var model: HomeViewModel

    private var isCompact: Bool { sizeClass == .compact }

    init(onStartSearch: @escaping () -> Void) {
        self.onStartSearch = onStartSearch
        _model = StateObject(wrappedValue: HomeViewModel(service: UnavailableDiscoveryService()))
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

                // 2. Sección "ESCUCHADO HACE POCO"
                recentlyPlayedSection

                // 3. Sección "TUS PODCASTS"
                followedPodcastsSection

                // 4. Secciones posteriores de catálogo y favoritos restilizadas con tokens Donda
                favoritesSection

                recommendationsSection

                discoverySection

                featuredArtistsSection

                topSongsSection
            }
            .padding(.bottom, 40)
            .responsiveHorizontalPadding()
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(DiegoTheme.background.ignoresSafeArea())
        .task {
            model.configure(service: environment.youtubeService)
            model.load()
            await model.loadRecommendations(basedOn: environment.library.history.map(\.mediaItem))
        }
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

    // MARK: - 2. Escuchado hace poco (historial reciente de música)

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        let historyRecords = environment.library.history
        let recentItems: [SavedTrack] = Array(historyRecords.prefix(10))

        if !recentItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("ESCUCHADO HACE POCO")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, record in
                            Button {
                                environment.play(record.mediaItem)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncImage(url: record.mediaItem.thumbnailURL) { phase in
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

                                    Text(record.title)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(1)

                                    Text(record.channelTitle)
                                        .dondaLabel()
                                        .foregroundStyle(DiegoTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 128, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reproducir \(record.title)")
                        }
                    }
                    .padding(.vertical, 4)
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

    // MARK: - Descubrimiento / Novedades

    @ViewBuilder
    private var discoverySection: some View {
        if case let .loaded(feed) = model.state, !feed.novedades.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("DESCUBRIMIENTO")

                mediaCarousel(feed.novedades)
            }
        }
    }

    // MARK: - Para ti (LLM)

    @ViewBuilder
    private var recommendationsSection: some View {
        if !model.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("PARA TI")
                mediaCarousel(model.recommendations)
            }
        }
    }

    private func mediaCarousel(_ items: [MediaItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        environment.play(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            AsyncImage(url: item.thumbnailURL) { phase in
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

                            Text(item.title)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(DiegoTheme.textPrimary)
                                .lineLimit(1)

                            Text(item.channelTitle)
                                .dondaLabel()
                                .foregroundStyle(DiegoTheme.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 128, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reproducir \(item.title)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Artistas destacados

    @ViewBuilder
    private var featuredArtistsSection: some View {
        if case let .loaded(feed) = model.state, !feed.artistas.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("ARTISTAS DESTACADOS")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(feed.artistas) { artist in
                            Button {
                                navState.navigate(to: .artistDetail(id: artist.id, name: artist.title))
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncImage(url: artist.thumbnailURL) { phase in
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

                                    Text(artist.title)
                                        .dondaLabel()
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(width: 128, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Artista \(artist.title)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Canciones más escuchadas

    @ViewBuilder
    private var topSongsSection: some View {
        let topSongs = topMostListenedSongs
        if !topSongs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("MÁS ESCUCHADAS")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(topSongs.enumerated()), id: \.element.id) { index, songItem in
                            Button {
                                environment.play(songItem.mediaItem)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncImage(url: songItem.mediaItem.thumbnailURL) { phase in
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

                                    Text(songItem.mediaItem.title)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(1)

                                    Text(songItem.mediaItem.channelTitle)
                                        .dondaLabel()
                                        .foregroundStyle(DiegoTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 128, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reproducir \(songItem.mediaItem.title)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Auxiliares de cálculo

    private struct TopSongItem: Identifiable {
        var id: String { mediaItem.id }
        let mediaItem: MediaItem
        let playCount: Int
    }

    private var topMostListenedSongs: [TopSongItem] {
        let history = environment.library.history
        guard !history.isEmpty else { return [] }
        var counts: [String: (item: MediaItem, count: Int)] = [:]
        for record in history {
            let item = record.mediaItem
            if let existing = counts[item.id] {
                counts[item.id] = (item, existing.count + 1)
            } else {
                counts[item.id] = (item, 1)
            }
        }
        return counts.values
            .map { TopSongItem(mediaItem: $0.item, playCount: $0.count) }
            .sorted { $0.playCount > $1.playCount }
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

/// Conformante provisional que impide acceder a la red antes de que el
/// servicio real se inyecte desde el entorno en el primer `.task`.
private struct UnavailableDiscoveryService: YouTubeDataServicing {
    func search(query: String, pageToken: String?) async throws -> SearchPage {
        throw YouTubeServiceError.unavailable
    }
    func discover() async throws -> DiscoveryFeed { throw YouTubeServiceError.unavailable }
    func artist(byChannelID: String) async throws -> ArtistDetail { throw YouTubeServiceError.unavailable }
    func album(byPlaylistID: String) async throws -> Album { throw YouTubeServiceError.unavailable }
    func radio(seed videoID: String) async throws -> [MediaItem] { [] }
    func podcastEpisodes(channelID: String, pageToken: String?) async throws -> PodcastEpisodePage {
        PodcastEpisodePage(episodes: [], hiddenShortCount: 0)
    }
    func searchChannel(_ query: String) async throws -> PodcastShow? { nil }
}
