import SwiftUI

/// Vista de detalle de un canal de podcast en el sistema de diseño Donda.
/// Muestra cabecera de programa, acciones de reproducción y seguimiento, y
/// la lista de episodios completos con progreso y descarga offline.
struct PodcastDetailView: View {
    let channelID: String
    let title: String

    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var navState: NavigationState

    @State private var episodes: [MediaItem] = []
    @State private var hiddenShortCount: Int = 0
    @State private var nextPageToken: String? = nil
    @State private var isLoadingMore: Bool = false
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var isFollowing: Bool = false
    @State private var progressVersion: UUID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    episodeListSection
                }
                .padding(.bottom, 32)
            }
        }
        .background(DiegoTheme.background.ignoresSafeArea())
        .onAppear {
            isFollowing = environment.library.isFollowing(channelID: channelID)
            progressVersion = UUID()
            loadEpisodes()
        }
        .onReceive(environment.queue.$currentIndex) { _ in
            progressVersion = UUID()
        }
        .onReceive(environment.player.$playbackState) { _ in
            progressVersion = UUID()
        }
    }

    // MARK: - Barra de navegación superior

    @ViewBuilder
    private var topBar: some View {
        if navState.canGoBack {
            HStack {
                Button {
                    navState.goBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("ATRÁS")
                            .dondaLabel()
                    }
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.outline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volver atrás")

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Miniatura del programa

    private var showThumbnailURL: URL? {
        if let followed = environment.library.followedShows().first(where: { $0.channelID == channelID }),
           let url = followed.thumbnailURL {
            return url
        }
        return episodes.first?.thumbnailURL
    }

    // MARK: - Cabecera

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                AsyncImage(url: showThumbnailURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        DiegoTheme.background
                    }
                }
                .frame(width: 118, height: 118)
                .clipped()
                .overlay(
                    Rectangle()
                        .stroke(DiegoTheme.hairline, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("PODCAST · YOUTUBE")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text(title)
                        .dondaTitle(size: 22)
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        if let target = mostRecentUnfinishedEpisode {
                            let inProgress = isEpisodeInProgress(target)
                            Button {
                                environment.playEpisode(target, channelID: channelID)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 11))
                                    Text(inProgress ? "REANUDAR" : "REPRODUCIR")
                                        .dondaLabel()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(DiegoTheme.textPrimary)
                                .foregroundStyle(DiegoTheme.background)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            toggleFollow()
                        } label: {
                            Text(isFollowing ? "SIGUIENDO" : "SEGUIR")
                                .dondaLabel()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isFollowing ? DiegoTheme.textPrimary : DiegoTheme.background)
                                .foregroundStyle(isFollowing ? DiegoTheme.background : DiegoTheme.textPrimary)
                                .overlay(
                                    Rectangle()
                                        .stroke(DiegoTheme.outline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("SOLO EPISODIOS COMPLETOS · \(hiddenShortCount) VÍDEOS DE MENOS DE 40 MIN OCULTOS")
                .dondaLabel()
                .foregroundStyle(DiegoTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Lista de episodios

    @ViewBuilder
    private var episodeListSection: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(DiegoTheme.textPrimary)
                Text("CARGANDO EPISODIOS…")
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textSecondary)
            }
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        } else if errorMessage != nil {
            VStack(spacing: 12) {
                Text("NO SE PUDIERON CARGAR LOS EPISODIOS.")
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    loadEpisodes()
                } label: {
                    Text("REINTENTAR")
                        .dondaLabel()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(DiegoTheme.background)
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .overlay(
                            Rectangle()
                                .stroke(DiegoTheme.outline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 48)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        } else if episodes.isEmpty {
            VStack(spacing: 8) {
                Text("NO HAY EPISODIOS DISPONIBLES.")
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textSecondary)
            }
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(episodes) { episode in
                    VStack(spacing: 0) {
                        episodeRow(episode)

                        Rectangle()
                            .fill(DiegoTheme.hairline)
                            .frame(height: 1)
                    }
                }

                if nextPageToken != nil {
                    Button(action: loadMoreEpisodes) {
                        Text(isLoadingMore ? "CARGANDO…" : "CARGAR MÁS EPISODIOS")
                            .dondaLabel()
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingMore)
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Fila de episodio

    private func episodeRow(_ episode: MediaItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                environment.playEpisode(episode, channelID: channelID)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    AsyncImage(url: episode.thumbnailURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            DiegoTheme.background
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipped()
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        if let publishedAt = episode.publishedAt {
                            Text(formatRelativeDate(publishedAt))
                                .dondaLabel()
                                .foregroundStyle(DiegoTheme.textSecondary)
                        }

                        Text(episode.title)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        episodeStatusView(for: episode)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            downloadButton(for: episode)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .id("\(episode.id)-\(progressVersion)")
    }

    // MARK: - Estado de reproducción de episodio

    @ViewBuilder
    private func episodeStatusView(for episode: MediaItem) -> some View {
        let p = environment.library.progress(videoID: episode.id)
        if let p, p.finished {
            Text("ESCUCHADO")
                .dondaLabel()
                .foregroundStyle(DiegoTheme.textSecondary)
        } else if let p, !p.finished, p.position > 0 {
            VStack(alignment: .leading, spacing: 4) {
                Text("QUEDAN \(formatRemaining(position: p.position, duration: p.duration))")
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
                                width: max(0, min(geo.size.width, geo.size.width * CGFloat(p.position / max(1, p.duration)))),
                                height: 1
                            )
                    }
                }
                .frame(height: 1)
            }
        } else if let durationSeconds = episode.durationSeconds {
            Text(formatDuration(durationSeconds))
                .dondaLabel()
                .foregroundStyle(DiegoTheme.textSecondary)
        }
    }

    // MARK: - Botón de descarga trailing

    private func downloadButton(for episode: MediaItem) -> some View {
        let state = environment.downloadManager.states[episode.id] ?? .notDownloaded

        return Button {
            switch state {
            case .downloaded:
                try? environment.downloadManager.removeDownload(videoID: episode.id)
            case .notDownloaded, .failed:
                environment.downloadManager.enqueue(episode, resolver: environment.player.resolver)
            case .queued, .downloading:
                break
            }
        } label: {
            Group {
                switch state {
                case .notDownloaded, .failed:
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DiegoTheme.textSecondary)
                case .queued:
                    Text("...")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                case .downloading(let progress):
                    Text("\(Int(progress * 100))%")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textPrimary)
                case .downloaded:
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DiegoTheme.textPrimary)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(downloadAccessibilityLabel(for: episode, state: state))
    }

    private func downloadAccessibilityLabel(for episode: MediaItem, state: DownloadState) -> String {
        switch state {
        case .notDownloaded:
            return "Descargar \(episode.title)"
        case .queued:
            return "En cola de descarga \(episode.title)"
        case .downloading(let p):
            return "Descargando \(episode.title), \(Int(p * 100))%"
        case .downloaded:
            return "Descargado. Tocar para eliminar \(episode.title)"
        case .failed:
            return "Reintentar descarga de \(episode.title)"
        }
    }

    // MARK: - Lógica de datos y seguimiento

    private var mostRecentUnfinishedEpisode: MediaItem? {
        if let inProgress = episodes.first(where: { ep in
            if let p = environment.library.progress(videoID: ep.id), !p.finished, p.position > 0 {
                return true
            }
            return false
        }) {
            return inProgress
        }
        return episodes.first
    }

    private func isEpisodeInProgress(_ item: MediaItem) -> Bool {
        guard let p = environment.library.progress(videoID: item.id) else { return false }
        return !p.finished && p.position > 0
    }

    private func toggleFollow() {
        if isFollowing {
            try? environment.library.unfollow(channelID: channelID)
            isFollowing = false
        } else {
            let show = PodcastShow(channelID: channelID, title: title, thumbnailURL: showThumbnailURL)
            try? environment.library.follow(show)
            isFollowing = true
        }
    }

    private func loadEpisodes() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let page = try await environment.youtubeService.podcastEpisodes(channelID: channelID, pageToken: nil)
                self.episodes = page.episodes
                self.hiddenShortCount = page.hiddenShortCount
                self.nextPageToken = page.nextPageToken
                self.isLoading = false
            } catch {
                self.errorMessage = "NO SE PUDIERON CARGAR LOS EPISODIOS."
                self.isLoading = false
            }
        }
    }

    private func loadMoreEpisodes() {
        guard let token = nextPageToken, !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            defer { isLoadingMore = false }
            guard let page = try? await environment.youtubeService.podcastEpisodes(channelID: channelID, pageToken: token) else { return }
            let known = Set(episodes.map(\.id))
            episodes += page.episodes.filter { !known.contains($0.id) }
            hiddenShortCount += page.hiddenShortCount
            nextPageToken = page.nextPageToken
        }
    }

    // MARK: - Formateadores de tiempo y fecha

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date()).uppercased()
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

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours) H \(minutes) MIN"
        } else {
            return "\(max(1, minutes)) MIN"
        }
    }
}
