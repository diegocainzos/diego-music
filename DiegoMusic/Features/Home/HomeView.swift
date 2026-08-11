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

    private var isCompact: Bool { sizeClass == .compact }

    init(onStartSearch: @escaping () -> Void) {
        self.onStartSearch = onStartSearch
        _model = StateObject(wrappedValue: HomeViewModel(service: UnavailableDiscoveryService()))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 24 : 32) {
                    // Header de Sección Principal
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ESCUCHA AHORA")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(DiegoTheme.accent)
                                .tracking(1.2)
                            Text("Explorar")
                                .font(.system(size: isCompact ? 30 : 38, weight: .bold, design: .default))
                                .foregroundStyle(DiegoTheme.textPrimary)
                        }
                        Spacer()
                        Button(action: onStartSearch) {
                            Image(systemName: "magnifyingglass")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(DiegoTheme.accent)
                                .padding(10)
                                .background(DiegoTheme.surface)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Buscar música")
                    }

                    // 1. Hero Carousel (Destacados Banners)
                    heroCarousel

                    // 2. Sección Novedades / Feed Principal
                    discoverySection
                }
                .padding(.top, isCompact ? 16 : 24)
                .padding(.bottom, 32)
                .responsiveHorizontalPadding()
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
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

    // MARK: - Hero Carousel (Banners Destacados horizontales 320-400pt)

    private var heroCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isCompact ? 14 : 20) {
                heroCard(
                    eyebrow: "SESIÓN EN DESTACADO",
                    title: "Hip-Hop & R&B Essentials",
                    subtitle: "Grandes clásicos y lo más reciente del panorama urbano.",
                    gradientColors: [Color.red.opacity(0.8), Color.purple.opacity(0.9)],
                    symbol: "music.mic"
                )

                heroCard(
                    eyebrow: "NUEVO ÁLBUM",
                    title: "Novedades de la Semana",
                    subtitle: "Los lanzamientos más escuchados seleccionados para ti.",
                    gradientColors: [Color.orange.opacity(0.8), Color.red.opacity(0.9)],
                    symbol: "sparkles"
                )

                heroCard(
                    eyebrow: "RADIO 24/7",
                    title: "Chill & Focus Beats",
                    subtitle: "Sesiones instrumentales perfectas para concentración.",
                    gradientColors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.9)],
                    symbol: "radio.fill"
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func heroCard(
        eyebrow: String,
        title: String,
        subtitle: String,
        gradientColors: [Color],
        symbol: String
    ) -> some View {
        Button(action: onStartSearch) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(eyebrow)
                            .font(.caption2.bold())
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(20)
            }
            .frame(width: isCompact ? 300 : 380, height: isCompact ? 190 : 220)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: gradientColors.first?.opacity(0.3) ?? .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(TilePressButtonStyle())
    }

    // MARK: - Sección Descubrimiento

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            switch model.state {
            case .idle, .loading:
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small).tint(DiegoTheme.accent)
                    Text("Cargando catálogo…").font(.callout).foregroundStyle(DiegoTheme.textSecondary)
                }
                .padding(.vertical, 20)
            case let .loaded(feed):
                if !feed.artistas.isEmpty {
                    artistSection(feed.artistas)
                }
                if !feed.novedades.isEmpty {
                    novedadesGridSection(feed.novedades)
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

    // MARK: - Artistas Destacados

    private func artistSection(_ artistas: [ArtistReference]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Artistas Destacados")
                    .font(.title2.bold())
                    .foregroundStyle(DiegoTheme.textPrimary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isCompact ? 14 : 18) {
                    ForEach(artistas) { artist in
                        Button {
                            withAnimation(reduceMotion ? nil : .default) {
                                path.append(.artist(id: artist.id, title: artist.title))
                            }
                        } label: {
                            VStack(spacing: 10) {
                                TrackArtwork(url: artist.thumbnailURL)
                                    .frame(width: isCompact ? 100 : 120, height: isCompact ? 100 : 120)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

                                Text(artist.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                                    .frame(width: isCompact ? 100 : 120)
                                    .foregroundStyle(DiegoTheme.textPrimary)
                            }
                        }
                        .buttonStyle(TilePressButtonStyle())
                        .accessibilityLabel("Artista \(artist.title)")
                    }
                }
            }
        }
    }

    // MARK: - Novedades Grid (Tarjetas 180x180pt con esquinas redondeadas de 10pt)

    private func novedadesGridSection(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Charts & Novedades")
                    .font(.title2.bold())
                    .foregroundStyle(DiegoTheme.textPrimary)
                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: isCompact ? 150 : 180), spacing: isCompact ? 14 : 18)],
                spacing: isCompact ? 16 : 22
            ) {
                ForEach(items) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : .default) {
                            environment.play(item)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            TrackArtwork(url: item.thumbnailURL)
                                .frame(height: isCompact ? 150 : 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DiegoTheme.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text(item.channelTitle)
                                    .font(.caption)
                                    .foregroundStyle(DiegoTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(TilePressButtonStyle())
                }
            }
        }
    }

    private var emptyText: some View {
        Text("Aún no hay novedades disponibles.")
            .font(.callout)
            .foregroundStyle(DiegoTheme.textSecondary)
    }
}

/// Estilo de botón interactivo con suave efecto al pulsar (Hover/Press Apple Music)
struct TilePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
