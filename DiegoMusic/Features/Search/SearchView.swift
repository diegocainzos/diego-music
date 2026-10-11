import SwiftUI

enum SearchDetailDestination: Identifiable {
    case artist(id: String, title: String)
    case album(id: String)

    var id: String {
        switch self {
        case let .artist(id, title): return "artist-\(id)-\(title)"
        case let .album(id): return "album-\(id)"
        }
    }
}

struct SearchView: View {
    @StateObject private var model: SearchViewModel
    @ObservedObject var library: LibraryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var navState: NavigationState

    let service: any YouTubeDataServicing
    let onPlay: (MediaItem) -> Void
    let onFavorite: (MediaItem) -> Void

    @State private var activeDestination: SearchDetailDestination?
    @State private var toastMessage: String?

    init(
        service: any YouTubeDataServicing,
        library: LibraryStore,
        onPlay: @escaping (MediaItem) -> Void,
        onFavorite: @escaping (MediaItem) -> Void
    ) {
        self.service = service
        _model = StateObject(wrappedValue: SearchViewModel(service: service, libraryStore: library))
        self.library = library
        self.onPlay = onPlay
        self.onFavorite = onFavorite
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("BUSCAR")
                    .dondaTitle(size: 14)
                    .tracking(6)
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                HStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .accessibilityHidden(true)

                        TextField(text: $model.query) {
                            Text("CANCIONES, ARTISTAS, PODCASTS")
                                .dondaLabel()
                                .foregroundStyle(DiegoTheme.textSecondary)
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { model.search() }

                        if !model.query.isEmpty {
                            Button {
                                model.query = ""
                                model.clearSearch()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DiegoTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Borrar búsqueda")
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(DiegoTheme.background)
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                    )

                    Button(action: { model.search() }) {
                        Text("BUSCAR")
                            .dondaLabel()
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(DiegoTheme.textPrimary)
                            .foregroundStyle(DiegoTheme.background)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
                .responsiveHorizontalPadding()

                scopeSelector
            }
            .padding(.bottom, 10)

            ZStack(alignment: .bottom) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let toastMessage {
                    Text(toastMessage)
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.background)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DiegoTheme.textPrimary)
                        .overlay(
                            Rectangle()
                                .stroke(DiegoTheme.outline, lineWidth: 1)
                        )
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(DiegoTheme.background.ignoresSafeArea())
        .sheet(item: $activeDestination) { destination in
            NavigationStack {
                ZStack {
                    DiegoTheme.background.ignoresSafeArea()
                    switch destination {
                    case let .artist(id, title):
                        ArtistView(
                            artistID: id,
                            artistTitle: title,
                            service: service,
                            onPlay: onPlay
                        )
                    case let .album(id):
                        AlbumView(
                            playlistID: id,
                            service: service,
                            onPlay: onPlay
                        )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { activeDestination = nil }
                    }
                }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toastMessage = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Selector de ámbito (Chips con estilo Donda)

    private var scopeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases) { scope in
                    let isSelected = model.activeScope == scope
                    Button {
                        withAnimation(reduceMotion ? nil : .default) {
                            model.changeScope(scope)
                        }
                    } label: {
                        Text(scope.title.uppercased())
                            .dondaLabel()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? DiegoTheme.textPrimary : DiegoTheme.background)
                            .foregroundStyle(isSelected ? DiegoTheme.background : DiegoTheme.textPrimary)
                            .overlay(
                                Rectangle()
                                    .stroke(DiegoTheme.outline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filtrar por \(scope.title)")
                    .accessibilityValue(isSelected ? "Seleccionado" : "No seleccionado")
                }
            }
            .responsiveHorizontalPadding()
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ámbito de búsqueda")
    }

    // MARK: - Contenido de Búsqueda

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            if model.recentQueries.isEmpty {
                EmptyStateView(
                    title: "Tu próxima escucha",
                    symbol: "dot.radiowaves.left.and.right",
                    description: "Escribe una consulta para explorar vídeos y podcasts."
                )
            } else {
                recentHistory
            }
        case .loading:
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(DiegoTheme.textPrimary)
                Text("SINTONIZANDO YOUTUBE…")
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .loaded(items):
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        VStack(spacing: 0) {
                            SearchResultRow(
                                item: item,
                                library: library,
                                onPlay: onPlay,
                                onFavorite: onFavorite,
                                onEnqueueNext: { track in
                                    environment.queue.enqueueNext(track)
                                    showToast("AÑADIDA A CONTINUACIÓN")
                                },
                                onSelectArtist: { id, title in
                                    navState.navigate(to: .artistDetail(id: id, name: title))
                                },
                                onSelectAlbum: { playlistID in
                                    navState.navigate(to: .albumDetail(id: playlistID, title: playlistID))
                                },
                                onSelectPodcast: { channelID, title in
                                    navState.navigate(to: .podcastDetail(channelID: channelID, title: title))
                                }
                            )

                            Rectangle()
                                .fill(DiegoTheme.hairline)
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.vertical, 10)
                .responsiveHorizontalPadding()
            }
            .scrollBounceBehavior(.basedOnSize)
        case .empty:
            if model.hasRawResults {
                EmptyStateView(
                    title: "Sin resultados para \(model.activeScope.title)",
                    symbol: "line.3.horizontal.decrease.circle",
                    description: "Ajusta el ámbito para ver más resultados."
                )
            } else {
                EmptyStateView(title: "Sin resultados", symbol: "waveform.slash", description: "Prueba una consulta distinta.")
            }
        case let .failed(message):
            EmptyStateView(
                title: "No llegó la señal",
                symbol: "exclamationmark.triangle",
                description: message,
                actionTitle: "Reintentar",
                action: { model.search() }
            )
        }
    }

    // MARK: - Historial reciente

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECIENTE")
                .dondaLabel()
                .tracking(4)
                .foregroundStyle(DiegoTheme.textSecondary)
                .responsiveHorizontalPadding()

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(model.recentQueries, id: \.self) { query in
                        Button { model.selectRecent(query) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DiegoTheme.textSecondary)
                                Text(query.uppercased())
                                    .dondaLabel()
                                    .foregroundStyle(DiegoTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DiegoTheme.textSecondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(DiegoTheme.background)
                            .overlay(
                                Rectangle()
                                    .stroke(DiegoTheme.hairline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Buscar \(query)")
                    }
                }
                .responsiveHorizontalPadding()
            }
        }
        .frame(maxWidth: 800, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Fila de Resultado de Búsqueda con soporte para Canales / Podcasts Donda

struct SearchResultRow: View {
    let item: MediaItem
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void
    let onFavorite: (MediaItem) -> Void
    let onEnqueueNext: (MediaItem) -> Void
    let onSelectArtist: (String, String) -> Void
    let onSelectAlbum: (String) -> Void
    var onSelectPodcast: ((String, String) -> Void)? = nil

    private var isChannel: Bool {
        item.kind == .channel
    }

    private var isFollowingChannel: Bool {
        library.isFollowing(channelID: item.id)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                handleRowTap()
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: item.thumbnailURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            DiegoTheme.background
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipped()
                    .overlay(
                        Rectangle()
                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(.body, design: .default, weight: .regular))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if isChannel {
                            Text("CANAL · PODCAST")
                                .dondaLabel()
                                .foregroundStyle(DiegoTheme.textSecondary)
                                .lineLimit(1)
                        } else {
                            Text(item.channelTitle)
                                .dondaLabel()
                                .foregroundStyle(DiegoTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChannel ? "Ver canal \(item.title)" : "Reproducir \(item.title)")

            if isChannel {
                channelFollowButton
            } else {
                mediaTrailingButtons
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(DiegoTheme.background)
    }

    private func handleRowTap() {
        if isChannel {
            if isFollowingChannel {
                onSelectPodcast?(item.id, item.title)
            } else {
                onSelectArtist(item.id, item.title)
            }
        } else {
            onPlay(item)
        }
    }

    // MARK: - Botón Seguir / Siguiendo para canales

    private var channelFollowButton: some View {
        Button {
            if isFollowingChannel {
                try? library.unfollow(channelID: item.id)
            } else {
                let show = PodcastShow(channelID: item.id, title: item.title, thumbnailURL: item.thumbnailURL)
                try? library.follow(show)
            }
        } label: {
            Text(isFollowingChannel ? "SIGUIENDO" : "SEGUIR")
                .dondaLabel()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isFollowingChannel ? DiegoTheme.textPrimary : DiegoTheme.background)
                .foregroundStyle(isFollowingChannel ? DiegoTheme.background : DiegoTheme.textPrimary)
                .overlay(
                    Rectangle()
                        .stroke(DiegoTheme.outline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowingChannel ? "Dejar de seguir \(item.title)" : "Seguir \(item.title)")
    }

    // MARK: - Botones trailing para canciones / vídeos / playlists

    private var mediaTrailingButtons: some View {
        HStack(spacing: 4) {
            Button { onPlay(item) } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reproducir \(item.title)")

            Button { onFavorite(item) } label: {
                Image(systemName: library.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.system(size: 13))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .frame(width: 36, height: 36)
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
                    onSelectArtist(item.channelTitle, item.channelTitle)
                } label: {
                    Label("Ir al artista (\(item.channelTitle))", systemImage: "person.wave.2")
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
                    .font(.system(size: 13))
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Más opciones para \(item.title)")
        }
    }
}
