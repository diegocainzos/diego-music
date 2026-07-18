import SwiftUI

struct PlayerDock: View {
    @ObservedObject var player: PlayerCoordinator
    @ObservedObject var queue: PlaybackQueue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        Group {
            if let current = queue.current {
                VStack(spacing: expanded ? 16 : 8) {
                    if expanded {
                        expandedPlayer(current)
                    } else {
                        compactPlayer(current)
                    }

                    if let error = player.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(DiegoTheme.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(expanded ? 16 : 10)
                .frame(maxWidth: expanded ? 1040 : .infinity)
                .background(.ultraThinMaterial)
                .background(DiegoTheme.paper.opacity(0.94))
                .overlay(alignment: .top) { Rectangle().fill(DiegoTheme.ink).frame(height: 2) }
                .shadow(color: DiegoTheme.ink.opacity(0.22), radius: 16, y: -4)
            } else {
                YouTubePlayerView(coordinator: player)
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func compactPlayer(_ current: MediaItem) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                compactWebPlayer
                compactMetadata(current)
                controls
                expandButton
            }

            VStack(spacing: 10) {
                compactWebPlayer
                HStack(spacing: 10) {
                    compactMetadata(current)
                    controls
                    expandButton
                }
            }
        }
    }

    private var compactWebPlayer: some View {
        YouTubePlayerView(coordinator: player)
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(DiegoTheme.ink, lineWidth: 2) }
    }

    private func compactMetadata(_ current: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(current.title).font(.headline).lineLimit(1)
            Text(current.channelTitle).font(.caption).foregroundStyle(DiegoTheme.ink.opacity(0.65)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expandedPlayer(_ current: MediaItem) -> some View {
        VStack(spacing: 14) {
            YouTubePlayerView(coordinator: player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(minWidth: 200, maxWidth: 640, minHeight: 200, maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(DiegoTheme.ink, lineWidth: 2) }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(current.title).font(.title3.bold()).lineLimit(2)
                    Text(current.channelTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    progressControl
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                controls
                expandButton
            }

            queueEditor
        }
    }

    private var controls: some View {
        HStack(spacing: 5) {
            Button(action: { player.previous() }) { Image(systemName: "backward.fill") }
                .disabled(!queue.canRetreat)
                .accessibilityLabel("Anterior")
            Button(action: { player.togglePlayback() }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 24, height: 24)
            }
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
                Button("Vaciar") { queue.clear() }
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
                            Button { queue.remove(id: item.id) } label: { Image(systemName: "trash") }
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
