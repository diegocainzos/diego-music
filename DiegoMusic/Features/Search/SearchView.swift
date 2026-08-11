import SwiftUI

struct SearchView: View {
    @StateObject private var model: SearchViewModel
    @ObservedObject var library: LibraryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onPlay: (MediaItem) -> Void
    let onFavorite: (MediaItem) -> Void

    init(
        service: any YouTubeDataServicing,
        library: LibraryStore,
        onPlay: @escaping (MediaItem) -> Void,
        onFavorite: @escaping (MediaItem) -> Void
    ) {
        _model = StateObject(wrappedValue: SearchViewModel(service: service, libraryStore: library))
        self.library = library
        self.onPlay = onPlay
        self.onFavorite = onFavorite
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(eyebrow: "Catálogo público", title: "Encuentra una frecuencia", color: DiegoTheme.accent)

                HStack(spacing: 12) {
                    TextField("Canción, artista o sesión…", text: $model.query)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(DiegoTheme.surface)
                        .clipShape(Capsule())
                        .overlay { Capsule().stroke(DiegoTheme.textPrimary.opacity(0.15), lineWidth: 1) }
                        .onChange(of: model.query) { model.queryDidChange() }
                        .onSubmit { model.search() }
                    Button(action: { model.search() }) {
                        Label("Buscar", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [.command])
                }

                scopeSelector
            }
            .padding(28)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Selector de ámbito

    private var scopeSelector: some View {
        HStack(spacing: 8) {
            ForEach(SearchScope.allCases) { scope in
                Button {
                    withAnimation(reduceMotion ? nil : .default) {
                        model.changeScope(scope)
                    }
                } label: {
                    Label(scope.title, systemImage: scope.symbol)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(model.activeScope == scope ? DiegoTheme.accent : DiegoTheme.surface)
                        .foregroundStyle(model.activeScope == scope ? .white : DiegoTheme.textPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filtrar por \(scope.title)")
                .accessibilityValue(model.activeScope == scope ? "Seleccionado" : "No seleccionado")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ámbito de búsqueda")
    }

    // MARK: - Contenido

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
                Text("Sintonizando YouTube…").font(.headline)
            }
        case let .loaded(items):
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 18)], spacing: 18) {
                    ForEach(items) { item in
                        SearchResultCard(
                            item: item,
                            library: library,
                            onPlay: onPlay,
                            onFavorite: onFavorite
                        )
                    }
                }
                .padding(28)
            }
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
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(model.recentQueries, id: \.self) { query in
                        Button { model.selectRecent(query) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(DiegoTheme.textSecondary)
                                Text(query)
                                    .foregroundStyle(DiegoTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Buscar \(query)")
                    }
                }
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SearchResultCard: View {
    let item: MediaItem
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void
    let onFavorite: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: item.thumbnailURL) { phase in
                switch phase {
                case let .success(image): image.resizable().scaledToFill()
                default:
                    ZStack {
                        DiegoTheme.surface
                        Image(systemName: "music.note").font(.largeTitle).foregroundStyle(DiegoTheme.accent)
                    }
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
            .clipped()

            Text(item.title).font(.headline).foregroundStyle(DiegoTheme.textPrimary).lineLimit(2)
            Text(item.channelTitle).font(.subheadline).foregroundStyle(DiegoTheme.textSecondary).lineLimit(1)

            HStack {
                Button { onPlay(item) } label: { Label("Reproducir", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButtonStyle())
                Button { onFavorite(item) } label: {
                    Image(systemName: library.isFavorite(item) ? "heart.fill" : "heart")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(library.isFavorite(item) ? "Quitar de favoritos" : "Añadir a favoritos")
                .accessibilityValue(library.isFavorite(item) ? "Favorito" : "No favorito")
                if !library.playlists.isEmpty {
                    Menu {
                        ForEach(library.playlists) { playlist in
                            Button(playlist.name) { try? library.add(item, to: playlist) }
                        }
                    } label: {
                        Image(systemName: "text.badge.plus")
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityLabel("Añadir a playlist")
                }
            }
        }
        .minimalCard()
    }
}
