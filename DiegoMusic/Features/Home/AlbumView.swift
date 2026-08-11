import SwiftUI

@MainActor
final class AlbumViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(Album)
        case failed(message: String)
    }

    @Published private(set) var state: State = .loading

    private let playlistID: String
    private let service: any YouTubeDataServicing
    private var task: Task<Void, Never>?

    init(playlistID: String, service: any YouTubeDataServicing) {
        self.playlistID = playlistID
        self.service = service
    }

    deinit { task?.cancel() }

    func load() {
        task?.cancel()
        if case .loading = state {} else { state = .loading }
        task = Task { [weak self, service, playlistID] in
            do {
                let album = try await service.album(byPlaylistID: playlistID)
                guard !Task.isCancelled else { return }
                self?.state = .loaded(album)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar el álbum."
                self?.state = .failed(message: message)
            }
        }
    }
}

struct AlbumView: View {
    let playlistID: String
    @StateObject private var model: AlbumViewModel
    let onPlay: (MediaItem) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var environment: AppEnvironment

    @State private var activeArtistSheet: (id: String, title: String)?
    @State private var toastMessage: String?

    init(playlistID: String, service: any YouTubeDataServicing, onPlay: @escaping (MediaItem) -> Void) {
        self.playlistID = playlistID
        self.onPlay = onPlay
        _model = StateObject(wrappedValue: AlbumViewModel(playlistID: playlistID, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                switch model.state {
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.regular).tint(DiegoTheme.accent)
                        Text("Cargando álbum…")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(DiegoTheme.textSecondary)
                    }
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity, alignment: .center)

                case let .failed(message):
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(DiegoTheme.accent)
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(DiegoTheme.textSecondary)
                        Button("Reintentar") { model.load() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity, alignment: .center)

                case let .loaded(album):
                    header(album)
                    tracklistTable(album.tracks)
                }
            }
            .responsiveHorizontalPadding()
            .padding(.vertical, 24)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .task { model.load() }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DiegoTheme.accent)
                    .clipShape(Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: Binding(
            get: { activeArtistSheet.map { ArtistSheetItem(id: $0.id, title: $0.title) } },
            set: { activeArtistSheet = $0.map { ($0.id, $0.title) } }
        )) { item in
            NavigationStack {
                ArtistView(
                    artistID: item.id,
                    artistTitle: item.title,
                    service: environment.youtubeService,
                    onPlay: onPlay
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { activeArtistSheet = nil }
                    }
                }
            }
            .tint(DiegoTheme.accent)
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toastMessage = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Header Estilo Apple Music Web

    @ViewBuilder
    private func header(_ album: Album) -> some View {
        let isCompact = sizeClass == .compact

        if isCompact {
            VStack(spacing: 16) {
                TrackArtwork(url: album.thumbnailURL)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("ÁLBUM")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text(album.title)
                        .font(.title2.bold())
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    if let channel = album.channelTitle {
                        Button {
                            activeArtistSheet = (id: channel, title: channel)
                        } label: {
                            Text(channel)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(DiegoTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Música • \(album.tracks.count) canciones")
                        .font(.caption)
                        .foregroundStyle(DiegoTheme.textSecondary)
                }

                actionButtons(album)
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: 28) {
                TrackArtwork(url: album.thumbnailURL)
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("ÁLBUM")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text(album.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .lineLimit(2)

                    if let channel = album.channelTitle {
                        Button {
                            activeArtistSheet = (id: channel, title: channel)
                        } label: {
                            Text(channel)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(DiegoTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Música • \(album.tracks.count) canciones")
                        .font(.subheadline)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Spacer().frame(height: 4)

                    actionButtons(album)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Botones Reproducir / Aleatorio (Cápsulas Apple Music)

    private func actionButtons(_ album: Album) -> some View {
        HStack(spacing: 12) {
            Button {
                if let first = album.tracks.first {
                    onPlay(first)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.bold))
                    Text("Reproducir")
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(DiegoTheme.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                if let randomTrack = album.tracks.randomElement() {
                    onPlay(randomTrack)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                        .font(.subheadline.weight(.bold))
                    Text("Aleatorio")
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(DiegoTheme.surface)
                .foregroundStyle(DiegoTheme.accent)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(DiegoTheme.accent.opacity(0.5), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tabla de Pistas (Estilo Apple Music Web)

    private func tracklistTable(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pistas")
                .font(.title3.bold())
                .foregroundStyle(DiegoTheme.textPrimary)

            if items.isEmpty {
                Text("Este álbum no contiene pistas reproducibles.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    // Cabecera de tabla
                    HStack(spacing: 12) {
                        Text("#")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .frame(width: 28, alignment: .center)

                        Text("TÍTULO")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DiegoTheme.textSecondary)

                        Spacer()

                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .frame(width: 32)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Divider().background(Color.white.opacity(0.1))
                    }

                    // Filas de pistas
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            AlbumTrackRow(
                                index: index + 1,
                                item: item,
                                library: environment.library,
                                onPlay: onPlay,
                                onEnqueueNext: { track in
                                    environment.queue.enqueueNext(track)
                                    showToast("Añadida a continuación")
                                },
                                onSelectArtist: { artistName in
                                    activeArtistSheet = (id: artistName, title: artistName)
                                }
                            )
                        }
                    }
                }
                .background(DiegoTheme.surface.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
        }
    }
}

// MARK: - Helper Item para Sheet de Artista

private struct ArtistSheetItem: Identifiable {
    let id: String
    let title: String
}

// MARK: - Fila de Pista de Álbum (Estilo Tabla Apple Music Web)

private struct AlbumTrackRow: View {
    let index: Int
    let item: MediaItem
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void
    let onEnqueueNext: (MediaItem) -> Void
    let onSelectArtist: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Button { onPlay(item) } label: {
                HStack(spacing: 12) {
                    Text("\(index)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .frame(width: 28, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .lineLimit(1)

                        Text(item.channelTitle)
                            .font(.caption)
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { onPlay(item) } label: {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DiegoTheme.accent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reproducir \(item.title)")

            Button { try? library.toggleFavorite(item) } label: {
                Image(systemName: library.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(library.isFavorite(item) ? DiegoTheme.accent : DiegoTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(library.isFavorite(item) ? "Quitar de favoritos" : "Añadir a favoritos")

            Menu {
                Button {
                    onEnqueueNext(item)
                } label: {
                    Label("Añadir a la cola", systemImage: "text.insert")
                }

                Button {
                    onSelectArtist(item.channelTitle)
                } label: {
                    Label("Ir al artista (\(item.channelTitle))", systemImage: "person.wave.2")
                }

                if !library.playlists.isEmpty {
                    Menu {
                        ForEach(library.playlists) { playlist in
                            Button(playlist.name) { try? library.add(item, to: playlist) }
                        }
                    } label: {
                        Label("Añadir a playlist", systemImage: "text.badge.plus")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Más opciones para \(item.title)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.05))
        }
    }
}
