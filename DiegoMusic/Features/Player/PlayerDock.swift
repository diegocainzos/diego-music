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
    @State private var showLyricsFromExpanded = false
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

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Carátula Central con Halo de Progreso Circular Interactivo
                        CircularHaloScrubber(
                            url: current.thumbnailURL,
                            currentTime: player.currentTime,
                            duration: player.duration,
                            progress: player.progress,
                            onSeek: { fraction in
                                player.seek(to: fraction)
                            }
                        )
                        .padding(.top, 12)

                        // Información del Tema + Botón Favorito
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(current.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(DiegoTheme.textPrimary)
                                    .lineLimit(1)

                                Button {
                                    expanded = false
                                    navState.navigate(to: .artistDetail(id: current.channelTitle, name: current.channelTitle))
                                } label: {
                                    Text(current.channelTitle)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(DiegoTheme.midnightTextSecondary)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            Button {
                                try? environment.library.toggleFavorite(current)
                            } label: {
                                Image(systemName: environment.library.isFavorite(current) ? "heart.fill" : "heart")
                                    .font(.system(size: 24))
                                    .foregroundStyle(environment.library.isFavorite(current) ? DiegoTheme.red : DiegoTheme.midnightTextSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(environment.library.isFavorite(current) ? "Quitar de favoritos" : "Añadir a favoritos")
                        }
                        .padding(.horizontal, 28)

                        // Consola de Controles de Reproducción (5 Botones con Play/Pause Elevado)
                        HStack(spacing: 26) {
                            // Shuffle
                            Button(action: { player.toggleShuffle() }) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(player.shuffleEnabled ? DiegoTheme.midnightAccent : DiegoTheme.midnightTextSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Barajar")

                            // Previous
                            Button(action: { player.previous() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(DiegoTheme.textPrimary)
                            }
                            .disabled(!queue.canRetreat && player.currentTime < 1)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Anterior")

                            // Central Play/Pause Disc (Elevated High-Contrast Disc)
                            Button(action: { player.togglePlayback() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 66, height: 66)
                                        .shadow(color: Color.black.opacity(0.35), radius: 14, y: 6)

                                    if player.isLoading {
                                        ProgressView()
                                            .tint(Color.black)
                                            .controlSize(.regular)
                                    } else {
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(Color.black)
                                            .offset(x: player.isPlaying ? 0 : 2)
                                    }
                                }
                            }
                            .disabled(player.playbackState == .resolving)
                            .buttonStyle(.plain)
                            .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")

                            // Next
                            Button(action: { player.next() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(DiegoTheme.textPrimary)
                            }
                            .disabled(!queue.canAdvance)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Siguiente")

                            // Repeat
                            Button(action: { player.cycleRepeat() }) {
                                Image(systemName: repeatSymbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(player.repeatMode == .off ? DiegoTheme.midnightTextSecondary : DiegoTheme.midnightAccent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Repetir")
                        }
                        .padding(.vertical, 4)

                        // Lista Flotante de Cola de Reproducción
                        queueGlassSection
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        expanded = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cerrar")
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            showLyricsFromExpanded = true
                        } label: {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DiegoTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Letras de la canción")

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
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DiegoTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Más opciones de reproducción")
                    }
                }
            }
            .sheet(isPresented: $showLyricsFromExpanded) {
                lyricsSheet(current)
            }
        }
        .tint(DiegoTheme.midnightAccent)
    }

    // MARK: - Lista de Cola de Reproducción Flotante en el fondo

    @ViewBuilder
    private var queueGlassSection: some View {
        if !queue.items.isEmpty {
            VStack(spacing: 6) {
                ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, item in
                    let isCurrent = (index == queue.currentIndex)
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                            player.selectFromQueue(at: index)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            // Miniatura (Thumbnail): Cuadrado con bordes redondeados a la izquierda
                            ZStack {
                                TrackArtwork(url: item.thumbnailURL)
                                    .frame(width: 46, height: 46)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                if isCurrent {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.black.opacity(0.40))
                                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "play.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(DiegoTheme.midnightAccent)
                                }
                            }

                            // Metadatos: Columna centrada verticalmente con Título y Artista
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: isCurrent ? .bold : .medium))
                                    .foregroundStyle(isCurrent ? DiegoTheme.midnightAccent : DiegoTheme.textPrimary)
                                    .lineLimit(1)

                                Text(item.channelTitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(DiegoTheme.midnightTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Duración a la derecha
                            if let duration = item.durationSeconds, duration > 0 {
                                Text(format(Double(duration)))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(DiegoTheme.midnightTextSecondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isCurrent ? Color.white.opacity(0.08) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
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
                    Button("Cerrar") {
                        showLyrics = false
                        showLyricsFromExpanded = false
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                }
            }
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
                LinearGradient(
                    colors: [DiegoTheme.midnightTop, DiegoTheme.midnightBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                TrackArtwork(url: queue.current?.thumbnailURL)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: reduceMotion ? 16 : 48)
                    .opacity(0.24)
                    .saturation(1.35)
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

// MARK: - Halo Circular de Progreso Interactivo (Circular Halo Scrubber)

struct CircularHaloScrubber: View {
    let url: URL?
    let currentTime: Double
    let duration: Double
    let progress: Double
    let onSeek: (Double) -> Void

    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0

    private var currentProgress: Double {
        isDragging ? dragProgress : progress
    }

    private var displayedCurrentTime: Double {
        if isDragging {
            return (dragProgress * duration).clamped(to: 0...max(duration, 1))
        }
        return currentTime
    }

    private var displayedRemainingTime: Double {
        let current = displayedCurrentTime
        return max(duration - current, 0)
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Anillo de Fondo Inactivo
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 4)
                    .frame(width: 254, height: 254)

                // Halo Difuso Brillante de Fondo (Ambient Glow)
                Circle()
                    .trim(from: 0, to: max(0.001, currentProgress))
                    .stroke(
                        DiegoTheme.midnightCyan.opacity(0.70),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 254, height: 254)
                    .blur(radius: 8)
                    .rotationEffect(.degrees(-90))

                // Anillo de Progreso Activo con Degradado Cyan/Cobalt
                Circle()
                    .trim(from: 0, to: max(0.001, currentProgress))
                    .stroke(
                        LinearGradient(
                            colors: [
                                DiegoTheme.midnightCyan,
                                DiegoTheme.midnightAccent,
                                DiegoTheme.midnightCyan
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 254, height: 254)
                    .rotationEffect(.degrees(-90))

                // Carátula Central Hero Artwork (Encuadrada perfectamente en el círculo)
                TrackArtwork(url: url)
                    .frame(width: 236, height: 236)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.40), radius: 18, y: 8)
            }
            .frame(width: 264, height: 264)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let center = CGPoint(x: 132, y: 132)
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var radians = atan2(dy, dx) + .pi / 2
                        if radians < 0 { radians += 2 * .pi }
                        let fraction = min(max(radians / (2 * .pi), 0), 1)
                        isDragging = true
                        dragProgress = fraction
                    }
                    .onEnded { value in
                        let center = CGPoint(x: 132, y: 132)
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var radians = atan2(dy, dx) + .pi / 2
                        if radians < 0 { radians += 2 * .pi }
                        let fraction = min(max(radians / (2 * .pi), 0), 1)
                        isDragging = false
                        onSeek(fraction)
                    }
            )

            // Tiempos Transcurrido y Restante
            HStack {
                Text(formatTime(displayedCurrentTime))
                    .monospacedDigit()
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DiegoTheme.midnightTextSecondary)

                Spacer()

                Text("-" + formatTime(displayedRemainingTime))
                    .monospacedDigit()
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DiegoTheme.midnightTextSecondary)
            }
            .padding(.horizontal, 36)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
