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
    @EnvironmentObject private var navState: NavigationState

    @State private var toastMessage: String?
    @State private var isFollowing = false

    init(artistID: String, artistTitle: String, service: any YouTubeDataServicing, onPlay: @escaping (MediaItem) -> Void) {
        self.artistID = artistID
        self.artistTitle = artistTitle
        self.onPlay = onPlay
        _model = StateObject(wrappedValue: ArtistViewModel(artistID: artistID, service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barra de Navegación Superior con Botón de Atrás
            topNavigationBar

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    switch model.state {
                    case .loading:
                        HStack(spacing: 12) {
                            ProgressView().controlSize(.regular).tint(DiegoTheme.textPrimary)
                            Text("CARGANDO PERFIL DE \(artistTitle.uppercased())…")
                                .dondaLabel()
                                .foregroundStyle(DiegoTheme.textSecondary)
                        }
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .center)

                    case let .failed(message):
                        VStack(spacing: 14) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                                .foregroundStyle(DiegoTheme.textSecondary)
                            Text(message)
                                .font(.callout)
                                .foregroundStyle(DiegoTheme.textSecondary)
                            Button("REINTENTAR") { model.load() }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .center)

                    case let .loaded(detail):
                        heroHeader(detail)
                        topTracksSection(detail.topTracks)
                        discographySection(detail.albums)
                        similarArtistsSection(detail.related)
                    }
                }
                .responsiveHorizontalPadding()
                .padding(.vertical, 24)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
        }
        .background(DiegoTheme.background.ignoresSafeArea())
        .task { model.load() }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.background)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(DiegoTheme.textPrimary)
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.outline, lineWidth: 1)
                    )
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Top Navigation Bar (Flecha arriba a la izquierda)

    private var topNavigationBar: some View {
        HStack {
            if navState.canGoBack {
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
            }

            Spacer()

            Text("ARTISTA")
                .dondaLabel()
                .foregroundStyle(DiegoTheme.textSecondary)

            Spacer()

            if navState.canGoBack {
                Color.clear.frame(width: 70, height: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func showToast(_ text: String) {
        withAnimation { toastMessage = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Header Donda de Artista

    @ViewBuilder
    private func heroHeader(_ detail: ArtistDetail) -> some View {
        let isCompact = sizeClass == .compact
        let title = detail.artist.title.isEmpty ? artistTitle : detail.artist.title

        if isCompact {
            VStack(spacing: 16) {
                TrackArtwork(url: detail.artist.thumbnailURL)
                    .frame(width: 150, height: 150)
                    .clipped()
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("ARTISTA")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text(title)
                        .dondaTitle(size: 26)
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

                actionButtons(detail.topTracks, artistTitle: title)
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .center, spacing: 28) {
                TrackArtwork(url: detail.artist.thumbnailURL)
                    .frame(width: 170, height: 170)
                    .clipped()
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("ARTISTA")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text(title)
                        .dondaTitle(size: 32)
                        .foregroundStyle(DiegoTheme.textPrimary)

                    if let bio = detail.artist.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.callout)
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .lineLimit(3)
                    }

                    Spacer().frame(height: 4)

                    actionButtons(detail.topTracks, artistTitle: title)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Botones de Acción Donda (Reproducir, Aleatorio, Seguir)

    private func actionButtons(_ topTracks: [MediaItem], artistTitle: String) -> some View {
        HStack(spacing: 12) {
            Button {
                if let first = topTracks.first {
                    onPlay(first)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                    Text("REPRODUCIR")
                        .dondaLabel()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(DiegoTheme.textPrimary)
                .foregroundStyle(DiegoTheme.background)
            }
            .buttonStyle(.plain)

            Button {
                if let randomTrack = topTracks.randomElement() {
                    onPlay(randomTrack)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 11))
                    Text("ALEATORIO")
                        .dondaLabel()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(DiegoTheme.background)
                .foregroundStyle(DiegoTheme.textPrimary)
                .overlay(
                    Rectangle()
                        .stroke(DiegoTheme.outline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                isFollowing.toggle()
                showToast(isFollowing ? "Siguiendo a \(artistTitle)" : "Dejaste de seguir a \(artistTitle)")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isFollowing ? "checkmark" : "plus")
                        .font(.system(size: 11))
                    Text(isFollowing ? "SIGUIENDO" : "SEGUIR")
                        .dondaLabel()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
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

    // MARK: - Sección Top Tracks Donda

    private func topTracksSection(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ÉXITOS POPULARES")
                .dondaLabel()
                .tracking(4)
                .foregroundStyle(DiegoTheme.textSecondary)

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
                                    navState.navigate(to: .albumDetail(id: albumTitle, title: albumTitle))
                                }
                            )

                            if index < min(items.count, 10) - 1 {
                                Rectangle()
                                    .fill(DiegoTheme.hairline)
                                    .frame(height: 1)
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
                .background(DiegoTheme.surface)
                .overlay(
                    Rectangle()
                        .stroke(DiegoTheme.hairline, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Sección Discografía y Álbumes Donda

    private func discographySection(_ albums: [Album]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DISCOGRAFÍA Y ÁLBUMES")
                    .dondaLabel()
                    .tracking(4)
                    .foregroundStyle(DiegoTheme.textSecondary)

                Spacer()

                if !albums.isEmpty {
                    Text("\(albums.count) LANZAMIENTOS")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                }
            }

            if albums.isEmpty {
                Text("No hay álbumes disponibles.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
                    ForEach(albums) { album in
                        Button {
                            navState.navigate(to: .albumDetail(id: album.id, title: album.title))
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                TrackArtwork(url: album.thumbnailURL)
                                    .frame(height: 160)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .overlay(
                                        Rectangle()
                                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(album.title)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(2)

                                    Text(album.channelTitle ?? "Álbum")
                                        .dondaLabel()
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

    // MARK: - Sección Artistas Similares Donda

    private func similarArtistsSection(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ARTISTAS SIMILARES")
                .dondaLabel()
                .tracking(4)
                .foregroundStyle(DiegoTheme.textSecondary)

            if items.isEmpty {
                Text("No hay artistas similares recomendados.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(items.suffix(6)) { item in
                            Button {
                                navState.navigate(to: .artistDetail(id: item.channelTitle, name: item.channelTitle))
                            } label: {
                                VStack(spacing: 8) {
                                    TrackArtwork(url: item.thumbnailURL)
                                        .frame(width: 110, height: 110)
                                        .clipped()
                                        .overlay(
                                            Rectangle()
                                                .stroke(DiegoTheme.hairline, lineWidth: 1)
                                        )

                                    Text(item.channelTitle)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(1)
                                        .frame(width: 110)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Fila de Canción Popular Donda

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
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .frame(width: 24, alignment: .center)

                    TrackArtwork(url: item.thumbnailURL)
                        .frame(width: 44, height: 44)
                        .clipped()
                        .overlay(
                            Rectangle()
                                .stroke(DiegoTheme.hairline, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .lineLimit(1)

                        Text(item.channelTitle)
                            .dondaLabel()
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
                    .font(.system(size: 11))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reproducir \(item.title)")

            Button { try? library.toggleFavorite(item) } label: {
                Image(systemName: library.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(library.isFavorite(item) ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
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
        .background(isHovered ? DiegoTheme.hairline : Color.clear)
        .onHover { isHovered = $0 }
    }
}
