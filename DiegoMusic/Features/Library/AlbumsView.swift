import SwiftUI

/// Álbumes locales derivados de forma conservadora (grupos por artista),
/// dado que los registros locales no almacenan un dato de álbum real.
struct AlbumsView: View {
    @ObservedObject var library: LibraryStore
    let query: String
    let onPlay: (MediaItem) -> Void

    private var albums: [LocalAlbum] {
        library.albums.filter { album in
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            return album.name.matches(query: query) || album.tracks.contains { $0.matches(query: query) }
        }
    }

    var body: some View {
        Group {
            if albums.isEmpty {
                EmptyStateView(
                    title: "Sin álbumes",
                    symbol: "square.stack",
                    description: "Los álbumes se agrupan localmente a partir de tus artistas guardados."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(albums) { album in
                        Section(header: Text(album.name).font(.headline)) {
                            ForEach(album.tracks) { track in
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