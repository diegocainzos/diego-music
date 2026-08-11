import SwiftUI

/// Artistas de la biblioteca: rejilla de avatares circulares inspirada en Apple Music.
/// Al hacer clic en un artista, navega a su página completa de artista en la app.
struct ArtistsView: View {
    @ObservedObject var library: LibraryStore
    let query: String
    let onPlay: (MediaItem) -> Void

    @EnvironmentObject private var navState: NavigationState

    private var artists: [LocalArtist] {
        library.artists.filter { artist in
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            return artist.name.matches(query: query) || artist.tracks.contains { $0.matches(query: query) }
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 24)
    ]

    var body: some View {
        Group {
            if artists.isEmpty {
                EmptyStateView(
                    title: "Sin artistas en la biblioteca",
                    symbol: "music.mic",
                    description: "Guarda o reproduce canciones para organizarlas por artista automáticamente."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Artistas guardados")
                            .font(.title2.bold())
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 28) {
                            ForEach(artists) { artist in
                                artistCard(artist)
                            }
                        }
                    }
                    .responsiveHorizontalPadding()
                    .padding(.vertical, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private func artistCard(_ artist: LocalArtist) -> some View {
        Button {
            navState.navigate(to: .artistDetail(id: artist.name, name: artist.name))
        } label: {
            VStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    TrackArtwork(url: artist.tracks.first?.mediaItem.thumbnailURL)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DiegoTheme.textPrimary.opacity(0.12), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)

                    // Botón de reproducción rápida
                    Button {
                        if let firstTrack = artist.tracks.first {
                            onPlay(firstTrack.mediaItem)
                        }
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(DiegoTheme.accent)
                            .background(Circle().fill(DiegoTheme.background))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: 4)
                    .accessibilityLabel("Reproducir canciones de \(artist.name)")
                }

                VStack(spacing: 3) {
                    Text(artist.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)

                    let count = artist.tracks.count
                    Text(count == 1 ? "1 canción" : "\(count) canciones")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DiegoTheme.textSecondary)
                }
            }
            .padding(12)
            .background(DiegoTheme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
