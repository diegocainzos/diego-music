import SwiftUI

enum DiscoveryRoute: Hashable {
    case artist(id: String, title: String)
    case album(id: String)
}

struct HomeView: View {
    let onStartSearch: () -> Void
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var model: HomeViewModel
    @State private var path: [DiscoveryRoute] = []

    /// True en pantallas compactas (iPhone): reduce tipografías y espaciado para
    /// aprovechar mejor la pantalla y mejorar la navegación.
    private var isCompact: Bool { sizeClass == .compact }

    init(onStartSearch: @escaping () -> Void) {
        self.onStartSearch = onStartSearch
        // El servicio se resuelve desde el entorno en `body` mediante `.task`.
        _model = StateObject(wrappedValue: HomeViewModel(service: UnavailableDiscoveryService()))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 22 : 26) {
                    SectionHeader(eyebrow: "Escucha privada", title: "Descubrir", color: DiegoTheme.accent)

                    hero

                    features

                    discoverySection
                }
                .padding(.top, isCompact ? 16 : 28)
                .padding(.bottom, 28)
                .responsiveHorizontalPadding()
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationDestination(for: DiscoveryRoute.self) { route in
                destination(for: route)
            }
        }
        .task {
            model.configure(service: environment.youtubeService)
            model.load()
        }
    }

    @ViewBuilder
    private func destination(for route: DiscoveryRoute) -> some View {
        switch route {
        case let .artist(id, title):
            ArtistView(artistID: id, artistTitle: title, service: environment.youtubeService, onPlay: environment.play)
        case let .album(id):
            AlbumView(playlistID: id, service: environment.youtubeService, onPlay: environment.play)
        }
    }

    /// Las tres tarjetas de características se apilan verticalmente en compacto
    /// (donde tres columnas son ilegibles) y en horizontal en pantallas amplias.
    @ViewBuilder
    private var features: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 12) {
                feature(title: "Explora", symbol: "waveform.path.ecg", text: "Busca música pública con metadatos de YouTube Data API.")
                feature(title: "Protege", symbol: "shield.lefthalf.filled", text: "Controla reglas locales y recupera la reproducción con un toque.")
                feature(title: "Colecciona", symbol: "square.stack.3d.up.fill", text: "Guarda favoritos y playlists solo en este dispositivo.")
            }
        } else {
            HStack(alignment: .top, spacing: 18) {
                feature(title: "Explora", symbol: "waveform.path.ecg", text: "Busca música pública con metadatos de YouTube Data API.")
                feature(title: "Protege", symbol: "shield.lefthalf.filled", text: "Controla reglas locales y recupera la reproducción con un toque.")
                feature(title: "Colecciona", symbol: "square.stack.3d.up.fill", text: "Guarda favoritos y playlists solo en este dispositivo.")
            }
        }
    }

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                eyebrow: "Contenido público",
                title: "Novedades y artistas",
                color: DiegoTheme.accent
            )

            switch model.state {
            case .idle, .loading:
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small).tint(DiegoTheme.accent)
                    Text("Cargando novedades…").font(.callout).foregroundStyle(DiegoTheme.textSecondary)
                }
            case let .loaded(feed):
                if !feed.artistas.isEmpty {
                    artistRow(feed.artistas)
                }
                if !feed.novedades.isEmpty {
                    novedadesGrid(feed.novedades)
                } else {
                    emptyText
                }
            case .empty:
                emptyText
            case let .failed(message):
                HStack(spacing: 10) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(DiegoTheme.textSecondary)
                    Button("Reintentar") { model.load() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private func artistRow(_ artistas: [ArtistReference]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Artistas").font(.title3.bold()).foregroundStyle(DiegoTheme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artistas) { artist in
                        Button {
                            withAnimation(reduceMotion ? nil : .default) {
                                path.append(.artist(id: artist.id, title: artist.title))
                            }
                        } label: {
                            VStack(spacing: 8) {
                                TrackArtwork(url: artist.thumbnailURL)
                                    .frame(width: isCompact ? 72 : 84, height: isCompact ? 72 : 84)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                                Text(artist.title)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: isCompact ? 72 : 84)
                                    .foregroundStyle(DiegoTheme.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Artista \(artist.title)")
                    }
                }
            }
        }
    }

    private func novedadesGrid(_ items: [MediaItem]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 160 : 240), spacing: isCompact ? 12 : 16)], spacing: isCompact ? 12 : 16) {
            ForEach(items) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .default) {
                        environment.play(item)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        TrackArtwork(url: item.thumbnailURL)
                            .frame(height: isCompact ? 110 : 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
                            .clipped()
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(isCompact ? .subheadline.bold() : .headline).foregroundStyle(DiegoTheme.textPrimary).lineLimit(2)
                            Text(item.channelTitle).font(.caption).foregroundStyle(DiegoTheme.textSecondary).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyText: some View {
        Text("Aún no hay novedades disponibles.")
            .font(.callout)
            .foregroundStyle(DiegoTheme.textSecondary)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            Text("DIEGO\nMUSIC")
                .font(.system(size: isCompact ? 40 : 58, weight: .black, design: .default))
                .tracking(-3)
                .foregroundStyle(DiegoTheme.textPrimary)
                .minimumScaleFactor(0.6)
            Text("Una máquina musical educativa, local y deliberadamente diferente.")
                .font(isCompact ? .headline.weight(.semibold) : .title3.weight(.semibold))
                .foregroundStyle(DiegoTheme.textSecondary)
                .frame(maxWidth: 520, alignment: .leading)
            Button(action: onStartSearch) {
                Label("Buscar música", systemImage: "arrow.up.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("Abre la sección de búsqueda")
        }
        .frame(maxWidth: .infinity, minHeight: isCompact ? 190 : 300, alignment: .leading)
        .minimalCard()
    }

    private func feature(title: String, symbol: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(isCompact ? .title3 : .title)
                    .foregroundStyle(DiegoTheme.accent)
                Text(title).font(isCompact ? .headline.bold() : .title2.bold()).foregroundStyle(DiegoTheme.textPrimary)
            }
            Text(text)
                .font(isCompact ? .footnote : .callout)
                .foregroundStyle(DiegoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalCard()
    }
}

/// Conformante provisional que impide acceder a la red antes de que el
/// servicio real se inyecte desde el entorno en el primer `.task`.
private struct UnavailableDiscoveryService: YouTubeDataServicing {
    func search(query: String, pageToken: String?) async throws -> SearchPage {
        throw YouTubeServiceError.unavailable
    }
    func discover() async throws -> DiscoveryFeed { throw YouTubeServiceError.unavailable }
    func artist(byChannelID: String) async throws -> ArtistDetail { throw YouTubeServiceError.unavailable }
    func album(byPlaylistID: String) async throws -> Album { throw YouTubeServiceError.unavailable }
}
