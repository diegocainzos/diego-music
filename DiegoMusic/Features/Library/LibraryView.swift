import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case songs = "Canciones"
    case albums = "Álbumes"
    case artists = "Artistas"
    case lists = "Listas"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .songs: return "music.note"
        case .albums: return "square.stack"
        case .artists: return "music.mic"
        case .lists: return "music.note.list"
        }
    }
}

/// Contenedor de la Biblioteca: sub-pestañas Canciones/Álbumes/Artistas/Listas,
/// búsqueda local instantánea, listado "Me gusta" y recomendaciones locales.
struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void

    @State private var section: LibrarySection = .songs
    @State private var query = ""
    @State private var showLiked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(eyebrow: "Solo en tu dispositivo", title: "Biblioteca", color: DiegoTheme.accent)
                .padding(.horizontal, 28)
                .padding(.top, 28)

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .accessibilityHidden(true)
                TextField("Buscar en tu biblioteca…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .accessibilityLabel("Buscar en tu biblioteca")
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(DiegoTheme.surface)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(DiegoTheme.textPrimary.opacity(0.15), lineWidth: 1) }
            .padding(.horizontal, 28)

            Picker("Sección", selection: $section) {
                ForEach(LibrarySection.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 28)
            .accessibilityLabel("Sección de la biblioteca")

            if !recommendations.isEmpty {
                recommendationsSection
                    .padding(.horizontal, 28)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - "Me gusta" (acceso al listado) y recomendaciones locales

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Para ti", systemImage: "sparkles")
                    .font(.title3.bold())
                    .foregroundStyle(DiegoTheme.textPrimary)
                Spacer()
                Button {
                    showLiked.toggle()
                } label: {
                    Label(showLiked ? "Me gusta" : "Corazón", systemImage: showLiked ? "heart.fill" : "heart")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(showLiked ? "Ver biblioteca" : "Ver canciones con corazón")
            }
            if showLiked {
                likedList
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(recommendations) { track in
                            recommendedCard(track)
                        }
                    }
                }
                .frame(height: 96)
            }
        }
        .padding(16)
        .background(DiegoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
    }

    private var likedList: some View {
        let liked = library.songs.filter { $0.matches(query: query) }
        return Group {
            if liked.isEmpty {
                Text("Aún no hay canciones con corazón.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(liked) { track in
                        LibraryTrackRow(
                            track: track,
                            isFavorite: true,
                            onPlay: { onPlay(track.mediaItem) },
                            onFavorite: { try? library.toggleFavorite(track.mediaItem) }
                        )
                    }
                }
            }
        }
    }

    private func recommendedCard(_ track: SavedTrack) -> some View {
        Button { onPlay(track.mediaItem) } label: {
            HStack(spacing: 10) {
                TrackArtwork(url: track.mediaItem.thumbnailURL)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.headline).lineLimit(1)
                    Text(track.channelTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(width: 260, alignment: .leading)
            .background(DiegoTheme.background.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recomendada: \(track.title) de \(track.channelTitle)")
    }

    private var recommendations: [SavedTrack] {
        library.recommendations.filter { $0.matches(query: query) }
    }

    // MARK: - Contenido por sección

    @ViewBuilder
    private var content: some View {
        switch section {
        case .songs:
            SongsView(library: library, query: query, onPlay: onPlay)
        case .albums:
            AlbumsView(library: library, query: query, onPlay: onPlay)
        case .artists:
            ArtistsView(library: library, query: query, onPlay: onPlay)
        case .lists:
            ListaView(library: library, query: query, onPlay: onPlay)
        }
    }
}