import Foundation
import SwiftUI

/// Barra de reproducción y reproductor expandido (sistema Donda).
struct PlayerDock: View {
    @ObservedObject var player: AudioPlayerCoordinator
    @ObservedObject var queue: PlaybackQueue
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var navState: NavigationState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lyricsProvider: LRCLibLyricsProvider
    @State private var expanded = false
    @State private var showLyrics = false
    @State private var showLyricsFromExpanded = false
    @State private var sliderValue: Double = 0
    @State private var isDraggingSlider = false
    @State private var artworkPulse = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    init(
        player: AudioPlayerCoordinator,
        queue: PlaybackQueue,
        lyricsProvider: LRCLibLyricsProvider = LRCLibLyricsProvider()
    ) {
        self.player = player
        self.queue = queue
        self.lyricsProvider = lyricsProvider
    }

    private var isPodcast: Bool {
        if case .podcast = player.context {
            return true
        }
        return false
    }

    var body: some View {
        Group {
            if let current = queue.current {
                miniPlayerBar(current)
                    .sheet(isPresented: $expanded) {
                        expandedPlayerSheet(current)
                            .presentationBackground(DiegoTheme.background)
                            .presentationDragIndicator(.hidden)
                    }
                    .sheet(isPresented: $showLyrics) {
                        lyricsSheet(current)
                            .presentationBackground(DiegoTheme.background)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mini-player (Collapsed State)

    private func miniPlayerBar(_ current: MediaItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TrackArtwork(url: current.thumbnailURL)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(current.title)
                        .font(.system(size: 13, design: .monospaced))
                        .textCase(.uppercase)
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .lineLimit(1)

                    Text(current.channelTitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    player.togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")

                if isPodcast {
                    Button {
                        player.skip(by: 30)
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 18))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Avanzar 30 segundos")
                } else {
                    Button {
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(queue.canAdvance ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .disabled(!queue.canAdvance)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Siguiente")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                expanded = true
            }

            miniPlayerProgressBar
        }
        .background(DiegoTheme.background)
        .overlay(alignment: .top) {
            if horizontalSizeClass != .compact {
                Rectangle()
                    .fill(DiegoTheme.hairline)
                    .frame(height: 1)
            }
        }
    }

    private var miniPlayerProgressBar: some View {
        GeometryReader { geo in
            let progress = player.duration > 0 ? min(max(player.currentTime / player.duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(DiegoTheme.hairline)
                    .frame(height: 1)

                Rectangle()
                    .fill(DiegoTheme.textPrimary)
                    .frame(width: geo.size.width * CGFloat(progress), height: 1)
            }
        }
        .frame(height: 1)
    }

    // MARK: - Expanded Player (Donda)

    private func expandedPlayerSheet(_ current: MediaItem) -> some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    headerView(current)
                    artworkView(current)
                    titleSection(current)
                    progressSection
                    controlsSection(current)
                    belowControlsSection(current)

                    if !isPodcast {
                        queueSection
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(DiegoTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .automatic)
            .overlay(alignment: .bottom) {
                if let message = toastMessage {
                    Text(message)
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DiegoTheme.background)
                        .overlay(
                            Rectangle()
                                .stroke(DiegoTheme.outline, lineWidth: 1)
                        )
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
            .sheet(isPresented: $showLyricsFromExpanded) {
                lyricsSheet(current)
                    .presentationBackground(DiegoTheme.background)
            }
            .onAppear {
                sliderValue = player.currentTime
                if player.isPlaying && !reduceMotion {
                    withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                        artworkPulse = true
                    }
                }
                if let seconds = player.lastResumeSeconds, seconds > 0 {
                    showToast("REANUDANDO EN \(formatTime(seconds))")
                }
            }
            .onChange(of: player.isPlaying) { _, isPlaying in
                if isPlaying && !reduceMotion {
                    withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                        artworkPulse = true
                    }
                } else {
                    withAnimation(.default) {
                        artworkPulse = false
                    }
                }
            }
            .onChange(of: player.lastResumeSeconds) { _, seconds in
                if let seconds, seconds > 0 {
                    showToast("REANUDANDO EN \(formatTime(seconds))")
                }
            }
            .onChange(of: player.errorMessage) { _, error in
                if let error, error.localizedCaseInsensitiveContains("radio") {
                    showToast(error)
                }
            }
        }
    }

    // MARK: - Header

    private func headerView(_ current: MediaItem) -> some View {
        HStack(spacing: 8) {
            Button {
                expanded = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar")
            .frame(width: 80, alignment: .leading)

            Spacer()

            Group {
                if case .podcast(let channelID) = player.context {
                    Button {
                        expanded = false
                        navState.navigate(to: .podcastDetail(channelID: channelID, title: current.channelTitle))
                    } label: {
                        Text(current.channelTitle)
                            .dondaLabel()
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ver programa \(current.channelTitle)")
                } else {
                    Text(player.radioSeedTitle != nil ? "RADIO" : "REPRODUCIENDO")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if !isPodcast {
                    Button {
                        showLyricsFromExpanded = true
                    } label: {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 16))
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Letras de la canción")
                }

                ellipsisMenu(current)
            }
            .frame(width: 80, alignment: .trailing)
        }
    }

    private func ellipsisMenu(_ current: MediaItem) -> some View {
        Menu {
            Button {
                expanded = false
                navState.navigate(to: .albumDetail(id: current.title, title: current.title))
            } label: {
                Label("Ir al álbum", systemImage: "square.stack")
            }

            Button {
                expanded = false
                navState.navigate(to: .artistDetail(id: current.channelTitle, name: current.channelTitle))
            } label: {
                Label("Ir al artista", systemImage: "music.mic")
            }

            Divider()

            if !environment.library.playlists.isEmpty {
                Menu {
                    ForEach(environment.library.playlists) { playlist in
                        Button(playlist.name) {
                            try? environment.library.add(current, to: playlist)
                        }
                    }
                } label: {
                    Label("Añadir a playlist", systemImage: "text.badge.plus")
                }
            }

            Button {
                let albumID = current.title
                try? environment.library.toggleSaveAlbum(
                    id: albumID,
                    title: current.title,
                    channelTitle: current.channelTitle,
                    thumbnailURL: current.thumbnailURL,
                    tracks: [current]
                )
            } label: {
                if environment.library.isAlbumSaved(id: current.title) {
                    Label("Quitar álbum de la biblioteca", systemImage: "bookmark.slash")
                } else {
                    Label("Salvar álbum en la librería", systemImage: "bookmark")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16))
                .foregroundStyle(DiegoTheme.textSecondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Más opciones de reproducción")
    }

    // MARK: - Artwork

    private func artworkView(_ current: MediaItem) -> some View {
        TrackArtwork(url: current.thumbnailURL)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .shadow(
                color: DiegoTheme.textPrimary.opacity(player.isPlaying && artworkPulse ? 0.06 : 0),
                radius: 40
            )
    }

    // MARK: - Title & Subtitle

    private func titleSection(_ current: MediaItem) -> some View {
        VStack(spacing: 6) {
            Text(current.title)
                .dondaTitle(size: 20)
                .foregroundStyle(DiegoTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(current.channelTitle)
                .dondaLabel()
                .foregroundStyle(DiegoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isDraggingSlider ? sliderValue : player.currentTime },
                    set: { sliderValue = $0 }
                ),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in
                    isDraggingSlider = editing
                    if editing {
                        sliderValue = player.currentTime
                    } else {
                        player.seek(toSeconds: sliderValue)
                    }
                }
            )
            .tint(DiegoTheme.textPrimary)

            HStack {
                let currentSeconds = isDraggingSlider ? sliderValue : player.currentTime
                Text(formatTime(currentSeconds))
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DiegoTheme.textSecondary)

                Spacer()

                let remaining = max(player.duration - currentSeconds, 0)
                Text("-" + formatTime(remaining))
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DiegoTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Controls Row

    private func controlsSection(_ current: MediaItem) -> some View {
        HStack {
            if isPodcast {
                PodcastSpeedButton(settings: environment.playbackSettings)

                Spacer()

                Button {
                    player.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 22))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retroceder 15 segundos")

                Spacer()

                playPauseSquareButton

                Spacer()

                Button {
                    player.skip(by: 30)
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 22))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Avanzar 30 segundos")

                Spacer()

                PodcastDownloadButton(
                    item: current,
                    downloadManager: environment.downloadManager,
                    resolver: environment.player.resolver
                )
            } else {
                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20))
                        .foregroundStyle(player.shuffleEnabled ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Barajar")

                Spacer()

                Button {
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22))
                        .foregroundStyle((!queue.canRetreat && player.currentTime < 1) ? DiegoTheme.textSecondary : DiegoTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(!queue.canRetreat && player.currentTime < 1)
                .buttonStyle(.plain)
                .accessibilityLabel("Anterior")

                Spacer()

                playPauseSquareButton

                Spacer()

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(!queue.canAdvance ? DiegoTheme.textSecondary : DiegoTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(!queue.canAdvance)
                .buttonStyle(.plain)
                .accessibilityLabel("Siguiente")

                Spacer()

                Button {
                    player.cycleRepeat()
                } label: {
                    Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                        .font(.system(size: 20))
                        .foregroundStyle(player.repeatMode == .off ? DiegoTheme.textSecondary : DiegoTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Repetir")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var playPauseSquareButton: some View {
        Button {
            player.togglePlayback()
        } label: {
            ZStack {
                Rectangle()
                    .stroke(DiegoTheme.textPrimary, lineWidth: 1)
                    .frame(width: 72, height: 72)

                if player.isLoading {
                    ProgressView()
                        .tint(DiegoTheme.textPrimary)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(DiegoTheme.textPrimary)
                }
            }
            .frame(width: 72, height: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")
    }

    // MARK: - Below Controls

    @ViewBuilder
    private func belowControlsSection(_ current: MediaItem) -> some View {
        if isPodcast {
            PodcastCaptionView(item: current, downloadManager: environment.downloadManager)
        } else {
            Button {
                if player.radioSeedTitle != nil {
                    player.stopRadio()
                } else {
                    player.startRadio()
                }
            } label: {
                Text(player.radioSeedTitle != nil ? "RADIO ACTIVA · PARAR" : "INICIAR RADIO")
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.outline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.radioSeedTitle != nil ? "Parar radio" : "Iniciar radio")
            .padding(.top, 4)
        }
    }

    // MARK: - Upcoming Queue (Music Only)

    @ViewBuilder
    private var queueSection: some View {
        if !queue.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                let headerText = player.radioSeedTitle.map { "RADIO DE “\($0)”" } ?? "A CONTINUACIÓN"
                Text(headerText)
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                VStack(spacing: 8) {
                    ForEach(Array(queue.items.prefix(20).enumerated()), id: \.offset) { index, item in
                        let isCurrent = (index == queue.currentIndex)
                        Button {
                            player.selectFromQueue(at: index)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    if isCurrent {
                                        Text("▶")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(DiegoTheme.textPrimary)
                                    }
                                }
                                .frame(width: 12)

                                TrackArtwork(url: item.thumbnailURL)
                                    .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(1)

                                    Text(item.channelTitle)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(DiegoTheme.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if let duration = item.durationSeconds, duration > 0 {
                                    Text(formatTime(Double(duration)))
                                        .font(.system(size: 11, design: .monospaced))
                                        .monospacedDigit()
                                        .foregroundStyle(DiegoTheme.textSecondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title) de \(item.channelTitle)")
                    }
                }
            }
        }
    }

    // MARK: - Lyrics Sheet

    private func lyricsSheet(_ current: MediaItem) -> some View {
        NavigationStack {
            LyricsView(
                provider: lyricsProvider,
                item: current,
                player: player
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        showLyrics = false
                        showLyricsFromExpanded = false
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DiegoTheme.textPrimary)
                }
            }
        }
        .presentationBackground(DiegoTheme.background)
        .tint(DiegoTheme.textPrimary)
    }

    // MARK: - Toasts

    private func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            toastMessage = text
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let totalSeconds = max(0, Int(seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Subcomponentes de Podcast

private struct PodcastSpeedButton: View {
    @ObservedObject var settings: PlaybackSettings

    var body: some View {
        Button {
            settings.cyclePodcastRate()
        } label: {
            Text(formattedRate)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DiegoTheme.textPrimary)
                .frame(width: 44, height: 32)
                .overlay(
                    Rectangle()
                        .stroke(DiegoTheme.outline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Velocidad de reproducción \(formattedRate)")
    }

    private var formattedRate: String {
        let rate = settings.podcastRate
        if abs(rate - 1.0) < 0.01 { return "1×" }
        if abs(rate - 1.25) < 0.01 { return "1.25×" }
        if abs(rate - 1.5) < 0.01 { return "1.5×" }
        if abs(rate - 1.75) < 0.01 { return "1.75×" }
        if abs(rate - 2.0) < 0.01 { return "2×" }
        return String(format: "%.2f×", rate)
    }
}

private struct PodcastDownloadButton: View {
    let item: MediaItem
    @ObservedObject var downloadManager: OfflineDownloadManager
    let resolver: any AudioStreamResolving

    private var state: DownloadState {
        downloadManager.states[item.id] ?? (downloadManager.isDownloaded(videoID: item.id) ? .downloaded : .notDownloaded)
    }

    var body: some View {
        Button {
            switch state {
            case .notDownloaded, .failed:
                downloadManager.enqueue(item, resolver: resolver)
            default:
                break
            }
        } label: {
            Group {
                switch state {
                case .downloaded:
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DiegoTheme.textPrimary)
                case .downloading:
                    ProgressView()
                        .controlSize(.small)
                        .tint(DiegoTheme.textPrimary)
                case .queued:
                    Image(systemName: "clock")
                        .font(.system(size: 18))
                        .foregroundStyle(DiegoTheme.textSecondary)
                case .notDownloaded, .failed:
                    Image(systemName: "arrow.down")
                        .font(.system(size: 18))
                        .foregroundStyle(DiegoTheme.textSecondary)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
    }

    private var accessibilityTitle: String {
        switch state {
        case .downloaded: return "Descargado"
        case .downloading: return "Descargando episodio"
        case .queued: return "En cola de descarga"
        case .notDownloaded, .failed: return "Descargar episodio"
        }
    }
}

private struct PodcastCaptionView: View {
    let item: MediaItem
    @ObservedObject var downloadManager: OfflineDownloadManager

    var body: some View {
        let isDownloaded = downloadManager.isDownloaded(videoID: item.id)
        Text("SE GUARDA LA POSICIÓN AL PAUSAR" + (isDownloaded ? " · DISPONIBLE SIN CONEXIÓN" : ""))
            .dondaLabel()
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(DiegoTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

// MARK: - TrackArtwork (Donda: Cuadrado, radio 0, borde hairline)

/// Carga la carátula a través de `ArtworkCache` compartida.
struct TrackArtwork: View {
    let url: URL?
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            DiegoTheme.background
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .overlay(
            Rectangle()
                .stroke(DiegoTheme.hairline, lineWidth: 1)
        )
        .task(id: url) {
            image = nil
            guard let url else { return }
            image = await ArtworkCache.shared.image(for: url)
        }
    }
}
