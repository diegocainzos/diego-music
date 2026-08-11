import SwiftUI

// MARK: - Lyrics Display State

enum LyricsDisplayState: Equatable {
    case loading
    case synced([LyricsLine])
    case plain(String)
    case instrumental
    case notFound
    case error(String)
}

// MARK: - Live Lyrics View (Apple Music Style)

/// Vista de letras sincronizadas estilo Apple Music con autoscroll,
/// línea activa brillante, tap-to-seek y fondo glassmorphism.
struct LyricsView: View {
    let service: LyricsService
    let item: MediaItem
    @ObservedObject var player: AudioPlayerCoordinator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayState: LyricsDisplayState = .loading

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Fondo glassmorphism con portada difuminada
                lyricsBackground

                // Contenido según estado
                switch displayState {
                case .loading:
                    loadingView
                case .synced(let lines):
                    SyncedLyricsContent(
                        lines: lines,
                        player: player,
                        reduceMotion: reduceMotion,
                        viewportHeight: geo.size.height
                    )
                case .plain(let text):
                    plainLyricsView(text)
                case .instrumental:
                    instrumentalView
                case .notFound:
                    notFoundView
                case .error(let message):
                    errorView(message)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: item.id) {
            displayState = .loading
            let result = await service.fetchResult(for: item)
            switch result {
            case .synced(let lines):
                displayState = .synced(lines)
            case .plain(let text):
                displayState = .plain(text)
            case .instrumental:
                displayState = .instrumental
            case .notFound:
                displayState = .notFound
            }
        }
    }

    // MARK: - Background

    private var lyricsBackground: some View {
        ZStack {
            Color.black

            TrackArtwork(url: item.thumbnailURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 60)
                .brightness(-0.3)
                .saturation(1.4)
                .scaleEffect(1.2)
                .clipped()

            Color.black.opacity(0.4)
        }
        .ignoresSafeArea()
    }

    // MARK: - Loading

    private var loadingView: some View {
        ProgressView()
            .tint(.white)
            .scaleEffect(1.2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Plain Lyrics

    private func plainLyricsView(_ text: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "text.quote")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text("Letras sin sincronización")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView {
                Text(text)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
            }
        }
    }

    // MARK: - Instrumental

    private var instrumentalView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            Text("Instrumental")
                .font(.title2.bold())
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Not Found

    private var notFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.4))
            Text("Letra no disponible")
                .font(.title2.bold())
                .foregroundStyle(.white.opacity(0.7))
            Text("No se encontraron letras para esta canción")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.4))
            Text("Error al cargar letras")
                .font(.title2.bold())
                .foregroundStyle(.white.opacity(0.7))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Synced Lyrics Content (Extracted for performance)

private struct SyncedLyricsContent: View {
    let lines: [LyricsLine]
    @ObservedObject var player: AudioPlayerCoordinator
    let reduceMotion: Bool
    let viewportHeight: CGFloat

    @State private var userScrolling = false
    @State private var scrollResetTask: Task<Void, Never>?

    private var activeIndex: Int? {
        let currentTime = player.currentTime
        // Find the last line whose startTime <= currentTime
        var result: Int?
        for (index, line) in lines.enumerated() {
            guard let start = line.startTime else { continue }
            if start <= currentTime {
                result = index
            } else {
                break // Lines are sorted by time
            }
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Top spacer for centering first line (35% of visible viewport height)
                    Spacer()
                        .frame(height: max(80, viewportHeight * 0.35))

                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        lyricsLineView(line: line, index: index)
                            .id(index)
                    }

                    // Bottom spacer for centering last line (35% of visible viewport height)
                    Spacer()
                        .frame(height: max(80, viewportHeight * 0.35))
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // Initial scroll to active line
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let target = activeIndex ?? 0
                    if lines.indices.contains(target) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
            .onChange(of: activeIndex) { _, newIndex in
                guard let newIndex, !userScrolling else { return }
                if reduceMotion {
                    proxy.scrollTo(newIndex, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { _ in
                        userScrolling = true
                        scrollResetTask?.cancel()
                    }
                    .onEnded { _ in
                        scrollResetTask?.cancel()
                        scrollResetTask = Task {
                            try? await Task.sleep(for: .seconds(3))
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                userScrolling = false
                            }
                        }
                    }
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Letras sincronizadas")
        .accessibilityValue(activeLineText ?? "")
    }

    @ViewBuilder
    private func lyricsLineView(line: LyricsLine, index: Int) -> some View {
        let isActive = activeIndex == index
        let isEmpty = line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if isEmpty {
            // Instrumental break / empty line — render as spacing
            Rectangle()
                .fill(Color.clear)
                .frame(height: 24)
                .id(index)
        } else {
            Text(line.text)
                .font(isActive ? .title.bold() : .title3.weight(.medium))
                .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.35))
                .shadow(
                    color: isActive ? .white.opacity(0.6) : .clear,
                    radius: isActive ? 8 : 0
                )
                .shadow(
                    color: isActive ? .white.opacity(0.3) : .clear,
                    radius: isActive ? 16 : 0
                )
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let time = line.startTime {
                        player.seek(toSeconds: time)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isActive)
                .accessibilityAddTraits(isActive ? .isSelected : [])
        }
    }

    private var activeLineText: String? {
        guard let index = activeIndex, lines.indices.contains(index) else { return nil }
        return lines[index].text
    }
}
