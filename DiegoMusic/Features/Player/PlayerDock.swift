import SwiftUI

struct PlayerDock: View {
    @ObservedObject var player: AudioPlayerCoordinator
    @ObservedObject var queue: PlaybackQueue
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var navState: NavigationState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lyricsService: LyricsService
    @Namespace private var queueAnimationNamespace
    @State private var expanded = false
    @State private var showLyrics = false
    @State private var showQueue = false

    init(
        player: AudioPlayerCoordinator,
        queue: PlaybackQueue,
        lyricsService: LyricsService = LyricsService()
    ) {
        self.player = player
        self.queue = queue
        self.lyricsService = lyricsService
    }

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        Group {
            if let current = queue.current {
                VStack(spacing: 0) {
                    if let error = player.errorMessage {
                        errorBanner(error)
                    }

                    playerBar(current)
                }
                .background(.thinMaterial)
                .background(ambientBackground)
                .overlay(alignment: .top) {
                    Divider()
                        .opacity(0.15)
                }
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: -4)
                .sheet(isPresented: $expanded) {
                    expandedPlayerSheet(current)
                }
                .sheet(isPresented: $showLyrics) {
                    lyricsSheet(current)
                }
                .sheet(isPresented: $showQueue) {
                    queueSheet
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Player Bar Principal (Estilo Apple Music Web)

    private func playerBar(_ current: MediaItem) -> some View {
        HStack(spacing: 16) {
            // Sección Izquierda: Carátula, Info y Favorito
            leftSection(current)
                .frame(maxWidth: isCompact ? .infinity : 280, alignment: .leading)

            // Sección Central: Scrubber y Controles principales
            if !isCompact {
                centerSection
                    .frame(maxWidth: .infinity)
            }

            // Sección Derecha: Modos, Volumen, Letras, Cola y Expandir
            rightSection
                .frame(alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Sección Izquierda

    private func leftSection(_ current: MediaItem) -> some View {
        HStack(spacing: 12) {
            Button { expanded = true } label: {
                TrackArtwork(url: current.thumbnailURL)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir reproducción en pantalla completa")

            VStack(alignment: .leading, spacing: 2) {
                Button { expanded = true } label: {
                    Text(current.title)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Abrir reproductor en pantalla completa")

                Button {
                    navState.navigate(to: .artistDetail(id: current.channelTitle, name: current.channelTitle))
                } label: {
                    Text(current.channelTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DiegoTheme.accent)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Button {
                try? environment.library.toggleFavorite(current)
            } label: {
                Image(systemName: environment.library.isFavorite(current) ? "heart.fill" : "heart")
                    .font(.subheadline)
                    .foregroundStyle(environment.library.isFavorite(current) ? DiegoTheme.accent : DiegoTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(environment.library.isFavorite(current) ? "Quitar de favoritos" : "Añadir a favoritos")
        }
    }

    // MARK: - Sección Central (Scrubber y Controles)

    private var centerSection: some View {
        VStack(spacing: 4) {
            // Scrubber Bar Interactivo
            scrubberBar

            // Botones Anterior, Play/Pausa, Siguiente
            HStack(spacing: 24) {
                Button(action: { player.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.body)
                }
                .disabled(!queue.canRetreat && player.currentTime < 1)
                .buttonStyle(.plain)
                .accessibilityLabel("Anterior")

                Button(action: { player.togglePlayback() }) {
                    Group {
                        if player.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(DiegoTheme.textPrimary)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                }
                .disabled(player.playbackState == .resolving)
                .buttonStyle(.plain)
                .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")

                Button(action: { player.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.body)
                }
                .disabled(!queue.canAdvance)
                .buttonStyle(.plain)
                .accessibilityLabel("Siguiente")
            }
            .foregroundStyle(DiegoTheme.textPrimary)
        }
    }

    // MARK: - Sección Derecha (Barajar, Repetir, Volumen, Letras, Cola)

    private var rightSection: some View {
        HStack(spacing: isCompact ? 10 : 14) {
            if !isCompact {
                // Barajar
                Button(action: { player.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                        .font(.subheadline)
                        .foregroundStyle(player.shuffleEnabled ? DiegoTheme.accent : DiegoTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Barajar")

                // Repetir
                Button(action: { player.cycleRepeat() }) {
                    Image(systemName: repeatSymbol)
                        .font(.subheadline)
                        .foregroundStyle(player.repeatMode == .off ? DiegoTheme.textSecondary : DiegoTheme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Repetir")

                // Slider de Volumen
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill")
                        .font(.caption2)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Slider(value: $player.volume, in: 0...1)
                        .frame(width: 80)
                        .tint(DiegoTheme.accent)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption2)
                        .foregroundStyle(DiegoTheme.textSecondary)
                }
            }

            // Play/Pause compacto en iPhone
            if isCompact {
                Button(action: { player.togglePlayback() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            // Letras
            Button { showLyrics = true } label: {
                Image(systemName: "quote.bubble")
                    .font(.subheadline)
                    .foregroundStyle(DiegoTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Letras de la canción")

            // Cola de reproducción
            Button { showQueue = true } label: {
                Image(systemName: "list.bullet")
                    .font(.subheadline)
                    .foregroundStyle(DiegoTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cola de reproducción")

            // Expandir a reproductor completo
            Button { expanded = true } label: {
                Image(systemName: "chevron.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiegoTheme.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Expandir reproductor")
        }
    }

    // MARK: - Scrubber Bar (Tiempo actual / Duración)

    private var scrubberBar: some View {
        HStack(spacing: 8) {
            Text(format(player.currentTime))
                .monospacedDigit()
                .font(.caption2)
                .foregroundStyle(DiegoTheme.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DiegoTheme.textPrimary.opacity(0.12))
                        .frame(height: 4)

                    Capsule()
                        .fill(DiegoTheme.accent)
                        .frame(width: max(4, geo.size.width * player.progress), height: 4)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard geo.size.width > 0 else { return }
                            let fraction = min(max(value.location.x / geo.size.width, 0), 1)
                            player.seek(to: fraction)
                        }
                )
            }
            .frame(height: 14)

            Text(format(player.duration))
                .monospacedDigit()
                .font(.caption2)
                .foregroundStyle(DiegoTheme.textSecondary)
        }
    }

    // MARK: - Reproductor Desplegable (Now Playing Sheet)

    private func expandedPlayerSheet(_ current: MediaItem) -> some View {
        NavigationStack {
            ZStack {
                ambientBackground

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        // Carátula Grande
                        TrackArtwork(url: current.thumbnailURL)
                            .frame(width: 260, height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.25), radius: 20, y: 10)
                            .padding(.top, 16)

                        // Información del Tema
                        VStack(spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(current.title)
                                        .font(.title2.bold())
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(2)

                                    Button {
                                        expanded = false
                                        navState.navigate(to: .artistDetail(id: current.channelTitle, name: current.channelTitle))
                                    } label: {
                                        Text(current.channelTitle)
                                            .font(.headline)
                                            .foregroundStyle(DiegoTheme.accent)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()

                                Button {
                                    try? environment.library.toggleFavorite(current)
                                } label: {
                                    Image(systemName: environment.library.isFavorite(current) ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundStyle(environment.library.isFavorite(current) ? DiegoTheme.accent : DiegoTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Scrubber Bar Grande
                        VStack(spacing: 6) {
                            scrubberBar
                        }
                        .padding(.horizontal, 24)

                        // Controles de Reproducción Completos
                        HStack(spacing: 32) {
                            Button(action: { player.toggleShuffle() }) {
                                Image(systemName: "shuffle")
                                    .font(.title3)
                                    .foregroundStyle(player.shuffleEnabled ? DiegoTheme.accent : DiegoTheme.textSecondary)
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.previous() }) {
                                Image(systemName: "backward.fill")
                                    .font(.title)
                                    .foregroundStyle(DiegoTheme.textPrimary)
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.togglePlayback() }) {
                                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(DiegoTheme.accent)
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.next() }) {
                                Image(systemName: "forward.fill")
                                    .font(.title)
                                    .foregroundStyle(DiegoTheme.textPrimary)
                            }
                            .buttonStyle(.plain)

                            Button(action: { player.cycleRepeat() }) {
                                Image(systemName: repeatSymbol)
                                    .font(.title3)
                                    .foregroundStyle(player.repeatMode == .off ? DiegoTheme.textSecondary : DiegoTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }

                        // Indicador de Scroll hacia abajo para Cola
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                            Text("Desliza para ver la cola de reproducción")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .padding(.top, 4)

                        // Sección Glassmórfica de Cola de Reproducción
                        queueGlassSection
                            .padding(.bottom, 32)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { expanded = false }
                }
                ToolbarItem(placement: .primaryAction) {
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
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(DiegoTheme.textPrimary)
                    }
                    .accessibilityLabel("Más opciones de reproducción")
                }
            }
        }
        .tint(DiegoTheme.accent)
    }

    // MARK: - Sección Glassmórfica de Cola de Reproducción integrada en el scroll

    @ViewBuilder
    private var queueGlassSection: some View {
        if !queue.items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("A continuación en la cola", systemImage: "list.bullet")
                        .font(.headline.bold())
                        .foregroundStyle(DiegoTheme.textPrimary)
                    Spacer()
                    Text("\(queue.items.count) canciones")
                        .font(.caption.bold())
                        .foregroundStyle(DiegoTheme.textSecondary)
                }

                VStack(spacing: 8) {
                    ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, item in
                        let isCurrent = (index == queue.currentIndex)
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                player.selectFromQueue(at: index)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    TrackArtwork(url: item.thumbnailURL)
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    if isCurrent {
                                        Rectangle()
                                            .fill(.black.opacity(0.35))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "play.fill")
                                            .font(.caption.bold())
                                            .foregroundStyle(DiegoTheme.accent)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                                        .foregroundStyle(isCurrent ? DiegoTheme.accent : DiegoTheme.textPrimary)
                                        .lineLimit(1)

                                    Text(item.channelTitle)
                                        .font(.caption)
                                        .foregroundStyle(DiegoTheme.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if isCurrent {
                                    Text("Sonando")
                                        .font(.caption2.bold())
                                        .foregroundStyle(DiegoTheme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(DiegoTheme.accent.opacity(0.15))
                                        .clipShape(Capsule())
                                        .matchedGeometryEffect(id: "queueBadge", in: queueAnimationNamespace)
                                }
                            }
                            .padding(10)
                            .background(
                                ZStack {
                                    if isCurrent {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(DiegoTheme.accent.opacity(0.14))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(DiegoTheme.accent.opacity(0.35), lineWidth: 1)
                                            )
                                            .matchedGeometryEffect(id: "queueHighlight", in: queueAnimationNamespace)
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.white.opacity(0.04))
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .appleMusicCard(cornerRadius: 16)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Sheet de Letras

    private func lyricsSheet(_ current: MediaItem) -> some View {
        NavigationStack {
            LyricsView(
                service: lyricsService,
                item: current,
                player: player
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { showLyrics = false }
                        .foregroundStyle(.white)
                }
            }
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
        }
        .tint(.white)
    }

    // MARK: - Sheet de Cola de Reproducción

    private var queueSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("A continuación (\(queue.items.count))")
                        .font(.headline)
                        .foregroundStyle(DiegoTheme.textPrimary)
                    Spacer()
                    Button("Vaciar") { player.clearQueue() }
                        .font(.subheadline.bold())
                        .disabled(queue.items.isEmpty)
                }

                List {
                    ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            TrackArtwork(url: item.thumbnailURL)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(item.id == queue.current?.id ? DiegoTheme.accent : DiegoTheme.textPrimary)
                                    .lineLimit(1)

                                Text(item.channelTitle)
                                    .font(.caption)
                                    .foregroundStyle(DiegoTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()

                            if item.id == queue.current?.id {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(DiegoTheme.accent)
                            }

                            Button { player.removeFromQueue(id: item.id) } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(DiegoTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { player.select(item) }
                    }
                    .onMove { source, destination in
                        queue.move(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
            }
            .padding(16)
            .background(DiegoTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { showQueue = false }
                }
            }
        }
        .tint(DiegoTheme.accent)
    }

    // MARK: - Fondo Ambiental

    @ViewBuilder
    private var ambientBackground: some View {
        GeometryReader { geo in
            ZStack {
                DiegoTheme.background
                TrackArtwork(url: queue.current?.thumbnailURL)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: reduceMotion ? 12 : 40)
                    .opacity(0.18)
                    .saturation(1.2)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Helpers de Formato y Símbolos

    private var repeatSymbol: String {
        switch player.repeatMode {
        case .one: return "repeat.1"
        case .all, .off: return "repeat"
        }
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(DiegoTheme.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Reintentar") { player.retry() }
                .font(.caption.bold())
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// Carga la carátula a través de `ArtworkCache` compartida.
struct TrackArtwork: View {
    let url: URL?
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            image = nil
            guard let url else { return }
            image = await ArtworkCache.shared.image(for: url)
        }
    }

    private var placeholder: some View {
        ZStack {
            DiegoTheme.surface
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(DiegoTheme.accent.opacity(0.6))
        }
    }
}
