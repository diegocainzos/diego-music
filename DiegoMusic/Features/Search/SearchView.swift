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
                SectionHeader(eyebrow: "Catálogo público", title: "Encuentra una frecuencia", color: DiegoTheme.accent)
                    .responsiveHorizontalPadding()

                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .accessibilityHidden(true)

                        TextField("Canción, artista o sesión…", text: $model.query)
                            .textFieldStyle(.plain)
                            .font(.body.weight(.medium))
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { model.search() }

                        if !model.query.isEmpty {
                            Button {
                                model.query = ""
                                model.clearSearch()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(DiegoTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Borrar búsqueda")
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(DiegoTheme.surface)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(DiegoTheme.textPrimary.opacity(0.12), lineWidth: 1) }

                    Button(action: { model.search() }) {
                        Text("Buscar")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [.command])
                }
                .responsiveHorizontalPadding()

                scopeSelector
            }
            .padding(.top, 14)
            .padding(.bottom, 10)

            ZStack(alignment: .bottom) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let toastMessage {
                    Text(toastMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DiegoTheme.accent)
                        .clipShape(Capsule())
                        .shadow(radius: 4)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
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

    // MARK: - Selector de ámbito (Chips desplazables horizontalmente)

    private var scopeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases) { scope in
                    Button {
                        withAnimation(reduceMotion ? nil : .default) {
                            model.changeScope(scope)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: scope.symbol)
                                .font(.caption.weight(.semibold))
                            Text(scope.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(model.activeScope == scope ? DiegoTheme.accent : DiegoTheme.surface)
                        .foregroundStyle(model.activeScope == scope ? .white : DiegoTheme.textPrimary)
                        .clipShape(Capsule())
                        .overlay {
                            if model.activeScope != scope {
                                Capsule().stroke(DiegoTheme.textPrimary.opacity(0.10), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filtrar por \(scope.title)")
                    .accessibilityValue(model.activeScope == scope ? "Seleccionado" : "No seleccionado")
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
                    description: "Escribe una consulta para explorar vídeos musicales reproducibles."
                )
            } else {
                recentHistory
            }
        case .loading:
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(DiegoTheme.accent)
                Text("Sintonizando YouTube…").font(.headline).foregroundStyle(DiegoTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .loaded(items):
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        SearchResultRow(
                            item: item,
                            library: library,
                            onPlay: onPlay,
                            onFavorite: onFavorite,
                            onEnqueueNext: { track in
                                environment.queue.enqueueNext(track)
                                showToast("Añadida a continuación")
                            },
                            onSelectArtist: { id, title in
                                activeDestination = .artist(id: id, title: title)
                            },
                            onSelectAlbum: { playlistID in
                                activeDestination = .album(id: playlistID)
                            }
                        )
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
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(DiegoTheme.textPrimary)
                .responsiveHorizontalPadding()

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(model.recentQueries, id: \.self) { query in
                        Button { model.selectRecent(query) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(DiegoTheme.textSecondary)
                                Text(query)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(DiegoTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundStyle(DiegoTheme.textSecondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(DiegoTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

// MARK: - Fila de Resultado de Búsqueda (Formato Lista limpia con Menú de 3 Puntos)

struct SearchResultRow: View {
    let item: MediaItem
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void
    let onFavorite: (MediaItem) -> Void
    let onEnqueueNext: (MediaItem) -> Void
    let onSelectArtist: (String, String) -> Void
    let onSelectAlbum: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { onPlay(item) } label: {
                HStack(spacing: 12) {
                    TrackArtwork(url: item.thumbnailURL)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

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
            .accessibilityLabel("Reproducir \(item.title)")

            HStack(spacing: 4) {
                Button { onPlay(item) } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DiegoTheme.accent)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reproducir \(item.title)")

                Button { onFavorite(item) } label: {
                    Image(systemName: library.isFavorite(item) ? "heart.fill" : "heart")
                        .font(.body)
                        .foregroundStyle(library.isFavorite(item) ? DiegoTheme.accent : DiegoTheme.textSecondary)
                        .frame(width: 38, height: 38)
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
                        .font(.body)
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .frame(width: 38, height: 38)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Más opciones para \(item.title)")
            }
        }
        .padding(10)
        .background(DiegoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
    }
}
