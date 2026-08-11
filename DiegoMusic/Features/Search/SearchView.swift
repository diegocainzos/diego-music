import SwiftUI

struct SearchView: View {
    @StateObject private var model: SearchViewModel
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void
    let onFavorite: (MediaItem) -> Void

    init(
        service: any YouTubeDataServicing,
        library: LibraryStore,
        onPlay: @escaping (MediaItem) -> Void,
        onFavorite: @escaping (MediaItem) -> Void
    ) {
        _model = StateObject(wrappedValue: SearchViewModel(service: service))
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
                        .onSubmit { model.search() }
                    Button(action: { model.search() }) {
                        Label("Buscar", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
            .padding(28)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            EmptyStateView(
                title: "Tu próxima escucha",
                symbol: "dot.radiowaves.left.and.right",
                description: "Escribe una consulta para explorar vídeos musicales reproducibles."
            )
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
            EmptyStateView(title: "Sin resultados", symbol: "waveform.slash", description: "Prueba una consulta distinta.")
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
