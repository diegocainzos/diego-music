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

    private var greetingTime: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Buenos días"
        case 12..<20: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    private var userName: String? {
        if case let .authenticated(user) = environment.authState {
            if let fullName = user.fullName, !fullName.isEmpty {
                return fullName
            }
            return user.email.components(separatedBy: "@").first
        }
        return nil
    }

    private var fullGreeting: String {
        if let name = userName, let firstName = name.components(separatedBy: " ").first, !firstName.isEmpty {
            return "\(greetingTime), \(firstName)"
        }
        return greetingTime
    }

    private var userInitials: String {
        guard let name = userName, !name.isEmpty else { return "DM" }
        let parts = name.split(separator: " ")
        if parts.count >= 2, let f = parts[0].first, let l = parts[1].first {
            return "\(f)\(l)".uppercased()
        } else if let f = name.first {
            return "\(f)".uppercased()
        }
        return "DM"
    }

    init(onStartSearch: @escaping () -> Void) {
        self.onStartSearch = onStartSearch
        _model = StateObject(wrappedValue: HomeViewModel(service: UnavailableDiscoveryService()))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 24 : 32) {
                    // Header de Sección Principal ("Escuchar / Listen Now")
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ESCUCHAR")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(DiegoTheme.accent)
                                .tracking(1.4)
                            Text(fullGreeting)
                                .font(.system(size: isCompact ? 28 : 34, weight: .bold, design: .default))
                                .foregroundStyle(DiegoTheme.textPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: onStartSearch) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [DiegoTheme.accent, DiegoTheme.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                    .shadow(color: DiegoTheme.accent.opacity(0.3), radius: 6, x: 0, y: 3)
                                Text(userInitials)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .accessibilityLabel("Perfil de usuario y búsqueda")
                    }

                    // 1. Hero Carousel (Destacados Banners)
                    heroCarousel

                    // 2. Sección "Hecho Para Ti" (Mixes Personalizados)
                    madeForYouSection

                    // 3. Historial Reciente (Escuchado Recientemente)
                    recentlyPlayedSection

                    // 4. Sección Descubrimiento (Top Artistas + Recomendaciones)
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

    // MARK: - Hero Carousel (Banners Destacados horizontales 340-380pt de ancho, 220pt de alto)

    private var heroCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isCompact ? 14 : 20) {
                heroCard(
                    eyebrow: "NUEVO ÁLBUM",
                    title: "Hip-Hop & R&B Essentials",
                    subtitle: "Grandes clásicos y lo más reciente del panorama urbano.",
                    gradientColors: [DiegoTheme.accent.opacity(0.9), Color.purple.opacity(0.9)],
                    symbol: "music.mic"
                )

                heroCard(
                    eyebrow: "ESTACIÓN RECOMENDADA",
                    title: "Novedades de la Semana",
                    subtitle: "Los lanzamientos más escuchados seleccionados para ti.",
                    gradientColors: [Color.orange.opacity(0.85), DiegoTheme.accent.opacity(0.9)],
                    symbol: "sparkles"
                )

                heroCard(
                    eyebrow: "DESTACADO DE HOY",
                    title: "Chill & Focus Beats",
                    subtitle: "Sesiones instrumentales perfectas para concentración.",
                    gradientColors: [Color.blue.opacity(0.85), Color.indigo.opacity(0.9)],
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

                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(eyebrow)
                            .font(.caption2.bold())
                            .tracking(1.4)
                            .foregroundStyle(DiegoTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.95))
                            .clipShape(Capsule())

                        Spacer()

                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer()

                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .default))
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
            .frame(width: isCompact ? 340 : 380, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: gradientColors.first?.opacity(0.3) ?? .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(TilePressButtonStyle())
    }

    // MARK: - Escuchado Recientemente (Fila horizontal de portadas cuadradas)

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        let historyItems = environment.library.history.map(\.mediaItem)
        let recentItems: [MediaItem] = {
            if !historyItems.isEmpty {
                return Array(historyItems.prefix(10))
            } else if let restoreItem = environment.playbackSettings.restoreState?.item {
                return [restoreItem]
            } else {
                return []
            }
        }()

        if !recentItems.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Escuchado recientemente")
                        .font(.title2.bold())
                        .foregroundStyle(DiegoTheme.textPrimary)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(recentItems) { item in
                            Button {
                                environment.play(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    TrackArtwork(url: item.thumbnailURL)
                                        .frame(width: 130, height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(DiegoTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(item.channelTitle)
                                            .font(.system(size: 11))
                                            .foregroundStyle(DiegoTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 130, alignment: .leading)
                                }
                            }
                            .buttonStyle(TilePressButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Hecho Para Ti (Mixes Personalizados Estilo Apple Music)

    private var madeForYouSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hecho para ti")
                .font(.title2.bold())
                .foregroundStyle(DiegoTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    mixCard(
                        title: "Mix de Descubrimiento",
                        subtitle: "Nuevas canciones seleccionadas según tu actividad",
                        gradientColors: [Color.pink.opacity(0.9), Color.purple.opacity(0.9)],
                        iconName: "sparkles"
                    )

                    mixCard(
                        title: "Mix de Favoritos",
                        subtitle: "Tus temas más reproducidos y guardados",
                        gradientColors: [Color.blue.opacity(0.85), Color.indigo.opacity(0.9)],
                        iconName: "heart.fill"
                    )

                    mixCard(
                        title: "Mix Urbana",
                        subtitle: "Ritmos latinos, reggaetón y hip-hop en tendencia",
                        gradientColors: [Color.orange.opacity(0.9), DiegoTheme.accent.opacity(0.9)],
                        iconName: "flame.fill"
                    )

                    mixCard(
                        title: "Mix Chill & Relax",
                        subtitle: "Sonidos suaves para desconectar",
                        gradientColors: [Color.teal.opacity(0.85), Color.cyan.opacity(0.9)],
                        iconName: "waveform"
                    )
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func mixCard(
        title: String,
        subtitle: String,
        gradientColors: [Color],
        iconName: String
    ) -> some View {
        Button(action: onStartSearch) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(width: 170, height: 170)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: gradientColors.first?.opacity(0.3) ?? .black.opacity(0.2), radius: 8, x: 0, y: 4)
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

    // MARK: - Top Artistas (Avatares Circulares 110pt)

    private func artistSection(_ artistas: [ArtistReference]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Artistas")
                    .font(.title2.bold())
                    .foregroundStyle(DiegoTheme.textPrimary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(artistas) { artist in
                        Button {
                            withAnimation(reduceMotion ? nil : .default) {
                                path.append(.artist(id: artist.id, title: artist.title))
                            }
                        } label: {
                            VStack(spacing: 8) {
                                TrackArtwork(url: artist.thumbnailURL)
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(DiegoTheme.textPrimary.opacity(0.08), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

                                Text(artist.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 110)
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

    // MARK: - Recomendaciones Grid (Tarjetas 160x160pt con esquinas redondeadas de 12pt)

    private func novedadesGridSection(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recomendaciones")
                    .font(.title2.bold())
                    .foregroundStyle(DiegoTheme.textPrimary)
                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
                spacing: 20
            ) {
                ForEach(items) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : .default) {
                            environment.play(item)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            TrackArtwork(url: item.thumbnailURL)
                                .frame(width: 160, height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(DiegoTheme.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text(item.channelTitle)
                                    .font(.system(size: 12))
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
