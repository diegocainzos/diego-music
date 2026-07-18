import SwiftUI

struct PlayerDock: View {
    @ObservedObject var player: AudioPlayerCoordinator
    @ObservedObject var queue: PlaybackQueue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        Group {
            if let current = queue.current {
                VStack(spacing: expanded ? 16 : 9) {
                    if expanded {
                        expandedPlayer(current)
                    } else {
                        compactPlayer(current)
                    }

                    if let error = player.errorMessage {
                        HStack(spacing: 10) {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(DiegoTheme.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Reintentar") { player.retry() }
                                .font(.caption.bold())
                                .buttonStyle(HiFiButtonStyle(color: DiegoTheme.red))
                        }
                    }
                }
                .padding(expanded ? 16 : 10)
                .frame(maxWidth: expanded ? 980 : .infinity)
                .background(.ultraThinMaterial)
                .background(DiegoTheme.paper.opacity(0.96))
                .overlay(alignment: .top) { Rectangle().fill(DiegoTheme.ink).frame(height: 2) }
                .shadow(color: DiegoTheme.ink.opacity(0.22), radius: 16, y: -4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func compactPlayer(_ current: MediaItem) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                artwork(current, size: 64)
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
                .foregroundStyle(DiegoTheme.ink.opacity(0.65))
                .lineLimit(1)
            stateLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expandedPlayer(_ current: MediaItem) -> some View {
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 20) {
                    artwork(current, size: 180)
                    expandedMetadata(current)
                }
                VStack(spacing: 14) {
                    artwork(current, size: 150)
                    expandedMetadata(current)
                }
            }
            queueEditor
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
            HStack(spacing: 12) {
                controls
                Spacer(minLength: 8)
                expandButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func artwork(_ item: MediaItem, size: CGFloat) -> some View {
        AsyncImage(url: item.thumbnailURL) { phase in
            switch phase {
            case let .success(image):
                image.resizable().scaledToFill()
            case .failure:
                artworkPlaceholder
            case .empty:
                ZStack {
                    artworkPlaceholder
                    ProgressView().tint(DiegoTheme.ink)
                }
            @unknown default:
                artworkPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(DiegoTheme.ink, lineWidth: 2) }
        .accessibilityHidden(true)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            DiegoTheme.yellow
            Circle().fill(DiegoTheme.ink).padding(13)
            Circle().fill(DiegoTheme.paper).padding(25)
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch player.playbackState {
        case .idle:
            Label("Preparado", systemImage: "circle")
        case .resolving:
            Label("Resolviendo en tu VPS…", systemImage: "network")
                .foregroundStyle(DiegoTheme.blue)
        case .buffering:
            Label("Cargando audio…", systemImage: "waveform")
                .foregroundStyle(DiegoTheme.blue)
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

    private var controls: some View {
        HStack(spacing: 6) {
            Button(action: { player.previous() }) { Image(systemName: "backward.fill") }
                .disabled(!queue.canRetreat && player.currentTime < 1)
                .accessibilityLabel("Anterior")
            Button(action: { player.togglePlayback() }) {
                Group {
                    if player.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    }
                }
                .font(.title3)
                .frame(width: 26, height: 26)
            }
            .disabled(player.playbackState == .resolving)
            .accessibilityLabel(player.isPlaying ? "Pausar" : "Reproducir")
            Button(action: { player.next() }) { Image(systemName: "forward.fill") }
                .disabled(!queue.canAdvance)
                .accessibilityLabel("Siguiente")
        }
        .buttonStyle(HiFiButtonStyle(color: DiegoTheme.yellow))
    }

    private var expandButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78)) {
                expanded.toggle()
            }
        } label: {
            Image(systemName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Contraer reproductor" : "Ampliar reproductor")
    }

    private var progressControl: some View {
        HStack {
            Text(format(player.currentTime)).monospacedDigit()
            Slider(
                value: Binding(get: { player.progress }, set: { player.seek(to: $0) }),
                in: 0...1
            )
            .disabled(player.duration <= 0)
            .tint(DiegoTheme.red)
            .accessibilityLabel("Posición de reproducción")
            .accessibilityValue("\(format(player.currentTime)) de \(format(player.duration))")
            Text(format(player.duration)).monospacedDigit()
        }
        .font(.caption)
    }

    private var queueEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COLA · \(queue.items.count)")
                    .font(.caption.bold())
                    .tracking(1.5)
                Spacer()
                Button("Vaciar") { player.clearQueue() }
                    .font(.caption.bold())
                    .disabled(queue.items.isEmpty)
            }
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Button { player.select(item) } label: {
                                HStack {
                                    Circle()
                                        .fill(item.id == queue.current?.id ? DiegoTheme.red : DiegoTheme.blue)
                                        .frame(width: 9, height: 9)
                                    Text(item.title).lineLimit(1)
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
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding(12)
        .background(DiegoTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(DiegoTheme.ink, lineWidth: 1) }
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}
