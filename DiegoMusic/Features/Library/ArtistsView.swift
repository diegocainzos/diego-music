import SwiftUI

/// Artistas de la biblioteca: rejilla de avatares circulares (160x160pt) al estilo Apple Music Web.
struct ArtistsView: View {
    @ObservedObject var library: LibraryStore
    let query: String
    let onPlay: (MediaItem) -> Void

    private var artists: [LocalArtist] {
        library.artists.filter { artist in
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            return artist.name.matches(query: query) || artist.tracks.contains { $0.matches(query: query) }
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 20)
    ]

    var body: some View {
        Group {
            if artists.isEmpty {
                EmptyStateView(
                    title: "Sin artistas",
                    symbol: "music.mic",
                    description: "Reproduce o guarda canciones para ver sus artistas aquí."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(artists) { artist in
                            artistAvatarCard(artist)
                        }
                    }
                    .padding(.vertical, 16)
                    .responsiveHorizontalPadding()
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private func artistAvatarCard(_ artist: LocalArtist) -> some View {
        VStack(spacing: 10) {
            Button {
                if let firstTrack = artist.tracks.first {
                    onPlay(firstTrack.mediaItem)
                }
            } label: {
                ZStack {
                    TrackArtwork(url: artist.tracks.first?.mediaItem.thumbnailURL)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(DiegoTheme.accent)
                        .background(Circle().fill(.black.opacity(0.4)))
                        .opacity(0.85)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(artist.name)
                    .font(.system(.body, design: .default, weight: .bold))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)

                Text("Artista")
                    .font(.caption)
                    .foregroundStyle(DiegoTheme.textSecondary)
            }
        }
    }
}
