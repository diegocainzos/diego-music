import SwiftUI

struct PlayerDock: View {
    @ObservedObject var player: AudioPlayerCoordinator
    @ObservedObject var queue: PlaybackQueue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Proveedor de letras inyectable (seam con el cambio `lyrics`).
    /// Por defecto usa el proveedor local/experimental; una app real lo sustituye
    /// por un `LyricsProviding` legítimo.
    private let lyricsService: LyricsService
    @State private var expanded = false
    @State private var showLyrics = false

    init(player: AudioPlayerCoordinator, queue: PlaybackQueue, lyricsService: LyricsService = LyricsService()) {
        self.player = player
        self.queue = queue
        self.lyricsService = lyricsService
    }

    var body: some View {
        Group {
            if let current = queue.current {
                VStack(spacing: expanded ? 18 : 10) {
                    if expanded {
                        expandedPlayer(current)
                    } else {
                        compactPlayer(current)
                    }

                    if let error = player.errorMessage {
                        errorBanner(error)
                    }
                }
                .padding(expanded ? 20 : 10)
                .frame(maxWidth: expanded ? 980 : .infinity)
                .background(ambientBackground)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 20, y: 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fondo ambiental derivado de la carátula

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

    // MARK: - Compacto

    private func compactPlayer(_ current: MediaItem) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                artwork(current, size: 60)
                compactMetadata(current)
                controls
                expandButton
            }

            VStack(spacing: 9) {
                HStack(spacing: 10) {
                    artwork(current, size: 54)
                    compactMetadata(current)
                    expandButton
                }
                controls
            }
        }
    }

    private func compactMetadata(_ current: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(current.title).font(.headline).lineLimit(1)
            Text(current.channelTitle)
                .font(.caption)
                .foregroundStyle(DiegoTheme.textSecondary)
                .lineLimit(1)
            stateLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ampliado

    private func expandedPlayer(_ current: MediaItem) -> some View {
        VStack(spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 22) {
                    artwork(current, size: 190)
                        .gesture(expandedSwipeGesture)
                    expandedMetadata(current)
                }
                VStack(spacing: 14) {
                    artwork(current, size: 170)
                        .gesture(expandedSwipeGesture)
                    expandedMetadata(current)
                }
            }
            queueEditor

            Button { showLyrics = true } label: {
                Label("Letras", systemImage: "text.quote")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Ver letras")
        }
        .contentShape(Rectangle())
        .gesture(expandedDismissGesture)
        .sheet(isPresented: $showLyrics) {
            if let current = queue.current {
                LyricsView(
                    service: lyricsService,
                    item: current,
                    currentTime: player.currentTime
                )
                .padding(20)
                .background(DiegoTheme.background.ignoresSafeArea())
                .preferredColorScheme(.light)
            }
        }
    }

    // MARK: - Gestos del ampliado

    private var expandedSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontal = value.translation.width
                if horizontal < -60 {
                    player.next()
                } else if horizontal > 60 {
                    player.previous()
                }
            }
    }

    private var expandedDismissGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard value.translation.height > 80 else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78)) {
                    expanded = false
                }
            }
    }

    private func expandedMetadata(_ current: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(current.title).font(.title2.bold()).lineLimit(2)
            Text(current.channelTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            stateLabel
            progressControl
            HStack(spacing: 20) {
                controls
                Spacer(minLength: 8)
                expandButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Carátula (vía caché compartida)

    private func artwork(_ item: MediaItem, size: CGFloat) -> some View {
        TrackArtwork(url: item.thumbnailURL)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
            .accessibilityHidden(true)
    }

    // MARK: - Estado / errores

    @ViewBuilder
    private var stateLabel: some View {
        switch player.playbackState {
        case .idle:
            Label("Preparado", systemImage: "circle")
        case .resolving:
            Label("Resolviendo en tu VPS…", systemImage: "network")
                .foregroundStyle(DiegoTheme.accent)
        case .buffering:
            Label("Cargando audio…", systemImage: "waveform")
                .foregroundStyle(DiegoTheme.accent)
        case .playing:
            Label("Reproduciendo", systemImage: "speaker.wave.2.fill")
                .foregroundStyle(DiegoTheme.green)
        case .paused:
            Label("En pausa", systemImage: "pause.circle.fill")
        case .ended:
            Label("Finalizada", systemImage: "checkmark.circle.fill")
        case .failed:
            Label("No disponible", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(DiegoTheme.red)
        }
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
    }

    // MARK: - Controles (SF Symbols, sin bordes de 2px)

    private var controls: some View {
        HStack(spacing: 20) {
            Button(action: { player.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(player.shuffleEnabled ? DiegoTheme.accent : DiegoTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Barajar")
            .accessibilityValue(player.shuffleEnabled ? "Activado" : "Desactivado")

            Button(action: { player.previous() }) {
                Image(systemName: "backward.fill").font(.title2)
            }
            .disabled(!queue.canRetreat && player.currentTime < 1)
            .accessibilityLabel("Anterior")

            Button(action: { player.togglePlayback() }) {
                Group {
                    if player.isLoading {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                }
                .frame(width: 56, height: 56)
                .background(DiegoTheme.accent)
                .foregroundStyle(.white)
                .clipShape(Circle())
                .shadow(color: DiegoTheme.accent.opacity(0.35), radius: 8, y: 4)
            }
            .disabled(player.playbackState == .resolving)
            .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")

            Button(action: { player.next() }) {
                Image(systemName: "forward.fill").font(.title2)
            }
            .disabled(!queue.canAdvance)
            .accessibilityLabel("Siguiente")

            Button(action: { player.cycleRepeat() }) {
                Image(systemName: repeatSymbol)
                    .font(.title3)
                    .foregroundStyle(player.repeatMode == .off ? DiegoTheme.textSecondary : DiegoTheme.accent)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Repetir")
            .accessibilityValue(repeatValue)
        }
        .foregroundStyle(DiegoTheme.textPrimary)
        .animation(reduceMotion ? nil : .default, value: player.isPlaying)
    }

    private var repeatSymbol: String {
        switch player.repeatMode {
        case .one: return "repeat.1"
        case .all, .off: return "repeat"
        }
    }

    private var repeatValue: String {
        switch player.repeatMode {
        case .off: return "Desactivado"
        case .all: return "Repetir lista"
        case .one: return "Repetir una"
        }
    }

    private var expandButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78)) {
                expanded.toggle()
            }
        } label: {
            Image(systemName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.body)
                .frame(width: 34, height: 34)
                .foregroundStyle(DiegoTheme.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Contraer reproductor" : "Ampliar reproductor")
    }

    // MARK: - Progreso fino

    private var progressControl: some View {
        HStack(spacing: 8) {
            Text(format(player.currentTime)).monospacedDigit().font(.caption)
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
            .frame(height: 22)
            .accessibilityElement()
            .accessibilityLabel("Posición de reproducción")
            .accessibilityValue("\(format(player.currentTime)) de \(format(player.duration))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    player.seek(to: min(player.progress + 0.05, 1))
                case .decrement:
                    player.seek(to: max(player.progress - 0.05, 0))
                @unknown default:
                    break
                }
            }
            Text(format(player.duration)).monospacedDigit().font(.caption)
        }
        .font(.caption)
    }

    // MARK: - Editor de cola

    private var queueEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COLA · \(queue.items.count)")
                    .font(.caption.bold())
                    .tracking(1.5)
                    .foregroundStyle(DiegoTheme.textPrimary)
                Spacer()
                Button("Vaciar") { player.clearQueue() }
                    .font(.caption.bold())
                    .disabled(queue.items.isEmpty)
            }
            List {
                ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 8) {
                        Button { player.select(item) } label: {
                            HStack {
                                Circle()
                                    .fill(item.id == queue.current?.id ? DiegoTheme.accent : DiegoTheme.textSecondary.opacity(0.6))
                                    .frame(width: 9, height: 9)
                                Text(item.title).lineLimit(1)
                                    .foregroundStyle(DiegoTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Button { queue.move(id: item.id, by: -1) } label: { Image(systemName: "arrow.up") }
                            .disabled(index == 0)
                            .accessibilityLabel("Subir en la cola")
                        Button { queue.move(id: item.id, by: 1) } label: { Image(systemName: "arrow.down") }
                            .disabled(index == queue.items.count - 1)
                            .accessibilityLabel("Bajar en la cola")
                        Button { player.removeFromQueue(id: item.id) } label: { Image(systemName: "trash") }
                            .accessibilityLabel("Eliminar de la cola")
                    }
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textPrimary)
                }
                .onMove { source, destination in
                    queue.move(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .frame(maxHeight: 150)
        }
        .padding(12)
        .background(DiegoTheme.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

/// Carga la carátula a través de `ArtworkCache` (la misma caché compartida que
/// publica Now Playing), en lugar de `AsyncImage`, para reutilizar la imagen y
/// evitar descargas duplicadas. Mantiene un placeholder ante fallo de red.
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
                .font(.title)
                .foregroundStyle(DiegoTheme.accent.opacity(0.6))
        }
    }
}
