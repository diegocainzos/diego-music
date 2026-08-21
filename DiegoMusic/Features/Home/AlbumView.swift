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
    @EnvironmentObject private var navState: NavigationState

    @State private var toastMessage: String?

    init(playlistID: String, service: any YouTubeDataServicing, onPlay: @escaping (MediaItem) -> Void) {
        self.playlistID = playlistID
        self.onPlay = onPlay
        _model = StateObject(wrappedValue: AlbumViewModel(playlistID: playlistID, service: service))
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
                            ProgressView().controlSize(.regular).tint(DiegoTheme.accent)
                            Text("Cargando álbum…")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(DiegoTheme.textSecondary)
                        }
                        .padding(.top, 60)
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
                        .padding(.top, 60)
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
        }
        .background(DiegoTheme.background.ignoresSafeArea())
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
                            .font(.body.weight(.bold))
                        Text("Atrás")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(DiegoTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(DiegoTheme.surface)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volver atrás")
            }

            Spacer()

            Text("Álbum")
                .font(.caption.bold())
                .tracking(1.2)
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

    // MARK: - Header Inmersivo (Título Arriba, Carátula al Centro, Autores Abajo)

    @ViewBuilder
    private func header(_ album: Album) -> some View {
        let isCompact = sizeClass == .compact

        VStack(spacing: 20) {
            // 1. TÍTULO ARRIBA
            VStack(spacing: 6) {
                Text("ÁLBUM")
                    .font(.caption.weight(.bold))
                    .tracking(2.0)
                    .foregroundStyle(DiegoTheme.accent)

                Text(album.title)
                    .font(isCompact ? .title.weight(.bold) : .system(size: 32, weight: .bold))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)

            // 2. CARÁTULA EN EL CENTRO CON RESPLANDOR AMBIENTAL
            ZStack {
                // Ambient Glow difuminado
                TrackArtwork(url: album.thumbnailURL)
                    .frame(width: isCompact ? 180 : 230, height: isCompact ? 180 : 230)
                    .blur(radius: 26)
                    .opacity(0.35)
                    .offset(y: 10)

                TrackArtwork(url: album.thumbnailURL)
                    .frame(width: isCompact ? 190 : 240, height: isCompact ? 190 : 240)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 8)
            }
            .accessibilityHidden(true)

            // 3. AUTORES / ARTISTAS Y METADATOS ABAJO
            VStack(spacing: 8) {
                if let channel = album.channelTitle, !channel.isEmpty {
                    Button {
                        navState.navigate(to: .artistDetail(id: channel, name: channel))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .font(.subheadline)
                            Text(channel)
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(DiegoTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(DiegoTheme.surfaceElevated.opacity(0.8))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(DiegoTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("\(album.tracks.count) canciones")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DiegoTheme.textSecondary)
            }

            // 4. BARRA DE ACCIONES FLOTANTE
            actionButtons(album)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - Botones de Acción (Barra Flotante en Cristal)

    private func actionButtons(_ album: Album) -> some View {
        HStack(spacing: 12) {
            // Botón Principal: Reproducir álbum completo en orden
            Button {
                if let first = album.tracks.first {
                    onPlay(first)
                    if album.tracks.count > 1 {
                        let remaining = Array(album.tracks.dropFirst())
                        environment.queue.replaceQueue(with: remaining)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.bold))
                    Text("Reproducir")
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 11)
                .background(DiegoTheme.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: DiegoTheme.accent.opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            // Modo Aleatorio
            Button {
                if let randomTrack = album.tracks.randomElement() {
                    onPlay(randomTrack)
                    let remaining = album.tracks.filter { $0.id != randomTrack.id }.shuffled()
                    environment.queue.replaceQueue(with: remaining)
                }
            } label: {
                Image(systemName: "shuffle")
                    .font(.body.weight(.bold))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(DiegoTheme.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reproducir álbum en modo aleatorio")

            // Descargar todo
            if !album.tracks.isEmpty,
               let resolverClient = environment.player.resolverClient {
                DownloadAllButton(
                    items: album.tracks,
                    downloadManager: environment.downloadManager,
                    resolver: resolverClient
                )
            }

            // Guardar álbum en la biblioteca
            let isSaved = environment.library.isAlbumSaved(id: album.id) || environment.library.isAlbumSaved(id: album.title)
            Button {
                do {
                    try environment.library.toggleSaveAlbum(album)
                    let nowSaved = environment.library.isAlbumSaved(id: album.id) || environment.library.isAlbumSaved(id: album.title)
                    showToast(nowSaved ? "Álbum guardado en la biblioteca" : "Álbum eliminado de la biblioteca")
                } catch {
                    showToast("Error al guardar el álbum")
                }
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(isSaved ? DiegoTheme.accent : DiegoTheme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(isSaved ? DiegoTheme.accent.opacity(0.15) : DiegoTheme.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isSaved ? DiegoTheme.accent.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Eliminar álbum de la biblioteca" : "Guardar álbum en la biblioteca")
        }
    }

    // MARK: - Tabla de Pistas Secuencial (Sin Enumerar `#`, Orden Estricto)

    private func tracklistTable(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Canciones")
                    .font(.title3.bold())
                    .foregroundStyle(DiegoTheme.textPrimary)

                Spacer()

                Text("\(items.count) pistas")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DiegoTheme.textSecondary)
            }

            if items.isEmpty {
                Text("Este álbum no contiene pistas reproducibles.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            AlbumTrackRow(
                                item: item,
                                isCurrent: environment.player.currentItem?.id == item.id,
                                isPlaying: environment.player.isPlaying && environment.player.currentItem?.id == item.id,
                                library: environment.library,
                                onPlay: {
                                    onPlay(item)
                                    let remaining = items.filter { $0.id != item.id }
                                    environment.queue.replaceQueue(with: remaining)
                                },
                                onEnqueueNext: { track in
                                    environment.queue.enqueueNext(track)
                                    showToast("Añadida a continuación")
                                },
                                onSelectArtist: { artistName in
                                    navState.navigate(to: .artistDetail(id: artistName, name: artistName))
                                }
                            )

                            if item.id != items.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
                .background(DiegoTheme.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Fila de Canción Secuencial (Limpia, Sin Número `#`, Con Estado Activo)

private struct AlbumTrackRow: View {
    let item: MediaItem
    let isCurrent: Bool
    let isPlaying: Bool
    @ObservedObject var library: LibraryStore
    let onPlay: () -> Void
    let onEnqueueNext: (MediaItem) -> Void
    let onSelectArtist: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Botón / Indicador de Reproducción Activa o Play
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    Group {
                        if isCurrent {
                            Image(systemName: isPlaying ? "waveform" : "pause.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(DiegoTheme.accent)
                                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isHovered ? DiegoTheme.accent : DiegoTheme.textSecondary.opacity(0.6))
                        }
                    }
                    .frame(width: 24, height: 24, alignment: .center)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.body.weight(isCurrent ? .bold : .medium))
                            .foregroundStyle(isCurrent ? DiegoTheme.accent : DiegoTheme.textPrimary)
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

            // Botón Favorito
            Button { try? library.toggleFavorite(item) } label: {
                Image(systemName: library.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(library.isFavorite(item) ? DiegoTheme.accent : DiegoTheme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(library.isFavorite(item) ? "Quitar de favoritos" : "Añadir a favoritos")

            // Menú de opciones rápidas
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isCurrent ? DiegoTheme.accent.opacity(0.08) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
        .onHover { isHovered = $0 }
    }
}
