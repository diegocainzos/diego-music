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
                        Text("ARTISTAS GUARDADOS")
                            .dondaLabel()
                            .tracking(4)
                            .foregroundStyle(DiegoTheme.textSecondary)
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
                        .clipped()
                        .overlay(
                            Rectangle()
                                .stroke(DiegoTheme.hairline, lineWidth: 1)
                        )

                    // Botón de reproducción rápida
                    Button {
                        if let firstTrack = artist.tracks.first {
                            onPlay(firstTrack.mediaItem)
                        }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(DiegoTheme.background)
                            .overlay(
                                Rectangle()
                                    .stroke(DiegoTheme.outline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(x: -4, y: -4)
                    .accessibilityLabel("Reproducir canciones de \(artist.name)")
                }

                VStack(spacing: 3) {
                    Text(artist.name)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)

                    let count = artist.tracks.count
                    Text(count == 1 ? "1 CANCIÓN" : "\(count) CANCIONES")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                }
            }
            .padding(12)
            .background(DiegoTheme.surface)
            .overlay(
                Rectangle()
                    .stroke(DiegoTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
