import SwiftUI

@MainActor
final class ArtistViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(ArtistDetail)
        case failed(message: String)
    }

    @Published private(set) var state: State = .loading

    private let artistID: String
    private let service: any YouTubeDataServicing
    private var task: Task<Void, Never>?

    init(artistID: String, service: any YouTubeDataServicing) {
        self.artistID = artistID
        self.service = service
    }

    deinit { task?.cancel() }

    func load() {
        task?.cancel()
        if case .loading = state {} else { state = .loading }
        task = Task { [weak self, service, artistID] in
            do {
                let detail = try await service.artist(byChannelID: artistID)
                guard !Task.isCancelled else { return }
                self?.state = .loaded(detail)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar el artista."
                self?.state = .failed(message: message)
            }
        }
    }
}

struct ArtistView: View {
    let artistID: String
    let artistTitle: String
    @StateObject private var model: ArtistViewModel
    let onPlay: (MediaItem) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var environment: AppEnvironment

    @State private var activeDetailSheet: DetailSheetItem?
    @State private var toastMessage: String?

    init(artistID: String, artistTitle: String, service: any YouTubeDataServicing, onPlay: @escaping (MediaItem) -> Void) {
        self.artistID = artistID
        self.artistTitle = artistTitle
        self.onPlay = onPlay
        _model = StateObject(wrappedValue: ArtistViewModel(artistID: artistID, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                switch model.state {
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.regular).tint(DiegoTheme.accent)
                        Text("Cargando perfil del artista…")
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

                case let .loaded(detail):
                    heroHeader(detail)
                    topTracksSection(detail.topTracks)
                    relatedSection(detail.related)
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
        .sheet(item: $activeDetailSheet) { item in
            NavigationStack {
                ZStack {
                    DiegoTheme.background.ignoresSafeArea()
                    switch item.kind {
                    case .artist:
                        ArtistView(
                            artistID: item.id,
                            artistTitle: item.title,
                            service: environment.youtubeService,
                            onPlay: onPlay
                        )
                    case .album:
                        AlbumView(
                            playlistID: item.id,
                            service: environment.youtubeService,
                            onPlay: onPlay
                        )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { activeDetailSheet = nil }
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

    // MARK: - Header Hero de Artista (Estilo Apple Music Web)

    @ViewBuilder
    private func heroHeader(_ detail: ArtistDetail) -> some View {
        let isCompact = sizeClass == .compact
        let title = detail.artist.title.isEmpty ? artistTitle : detail.artist.title

        if isCompact {
            VStack(spacing: 16) {
                TrackArtwork(url: detail.artist.thumbnailURL)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("ARTISTA")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    if let bio = detail.artist.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                }

                actionButtons(detail.topTracks)
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .center, spacing: 28) {
                TrackArtwork(url: detail.artist.thumbnailURL)
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 10)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("ARTISTA")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text(title)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(DiegoTheme.textPrimary)

                    if let bio = detail.artist.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.callout)
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .lineLimit(3)
                    }

                    Spacer().frame(height: 4)

                    actionButtons(detail.topTracks)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Botones de Acción Hero

    private func actionButtons(_ topTracks: [MediaItem]) -> some View {
        HStack(spacing: 12) {
            Button {
                if let first = topTracks.first {
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
                if let randomTrack = topTracks.randomElement() {
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

    // MARK: - Sección Top Tracks

    private func topTracksSection(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Canciones populares")
                .font(.title2.bold())
                .foregroundStyle(DiegoTheme.textPrimary)

            if items.isEmpty {
                Text("No hay canciones populares disponibles.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.prefix(10).enumerated()), id: \.element.id) { index, item in
                            ArtistTrackRow(
                                index: index + 1,
                                item: item,
                                library: environment.library,
                                onPlay: onPlay,
                                onEnqueueNext: { track in
                                    environment.queue.enqueueNext(track)
                                    showToast("Añadida a continuación")
                                },
                                onSelectAlbum: { albumTitle in
                                    activeDetailSheet = DetailSheetItem(id: albumTitle, title: albumTitle, kind: .album)
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

    // MARK: - Sección Artistas Similares / Relacionados

    private func relatedSection(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Lanzamientos y relacionados")
                .font(.title2.bold())
                .foregroundStyle(DiegoTheme.textPrimary)

            if items.isEmpty {
                Text("No hay lanzamientos relacionados.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)], spacing: 16) {
                    ForEach(items.prefix(8)) { item in
                        Button {
                            onPlay(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                TrackArtwork(url: item.thumbnailURL)
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(2)

                                    Text(item.channelTitle)
                                        .font(.caption)
                                        .foregroundStyle(DiegoTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Item para Sheet en Artista

private struct DetailSheetItem: Identifiable {
    enum Kind {
        case artist
        case album
    }

    let id: String
    let title: String
    let kind: Kind
}

// MARK: - Fila de Canción Popular en Perfil de Artista

private struct ArtistTrackRow: View {
    let index: Int
    let item: MediaItem
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void
    let onEnqueueNext: (MediaItem) -> Void
    let onSelectAlbum: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Button { onPlay(item) } label: {
                HStack(spacing: 12) {
                    Text("\(index)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .frame(width: 24, alignment: .center)

                    TrackArtwork(url: item.thumbnailURL)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                    onSelectAlbum(item.title)
                } label: {
                    Label("Ir al álbum", systemImage: "square.stack")
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
