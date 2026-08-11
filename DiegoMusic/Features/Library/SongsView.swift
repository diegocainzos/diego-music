import SwiftUI

/// Canciones de la biblioteca: favoritos con corazón (guardar/quitar) y reproducción.
struct SongsView: View {
    @ObservedObject var library: LibraryStore
    let query: String
    let onPlay: (MediaItem) -> Void

    private var filtered: [SavedTrack] {
        library.songs.filter { $0.matches(query: query) }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                EmptyStateView(
                    title: "Sin canciones",
                    symbol: "music.note",
                    description: query.isEmpty
                        ? "Guarda canciones desde Búsqueda para verlas aquí."
                        : "Ninguna canción coincide con tu búsqueda."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { track in
                        LibraryTrackRow(
                            track: track,
                            isFavorite: library.isFavorite(track.mediaItem),
                            onPlay: { onPlay(track.mediaItem) },
                            onFavorite: { try? library.toggleFavorite(track.mediaItem) }
                        )
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}