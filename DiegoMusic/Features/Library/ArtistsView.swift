import SwiftUI

/// Artistas locales derivados de favoritos e historial, agrupados por nombre.
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
                List {
                    ForEach(artists) { artist in
                        Section(header: Text(artist.name).font(.headline)) {
                            ForEach(artist.tracks) { track in
                                LibraryTrackRow(
                                    track: track,
                                    isFavorite: library.isFavorite(track.mediaItem),
                                    onPlay: { onPlay(track.mediaItem) },
                                    onFavorite: { try? library.toggleFavorite(track.mediaItem) }
                                )
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}