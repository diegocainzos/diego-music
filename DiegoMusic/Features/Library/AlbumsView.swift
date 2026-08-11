import SwiftUI

/// Álbumes de la biblioteca: rejilla de tarjetas cuadradas (180x180pt) al estilo Apple Music Web.
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

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]

    var body: some View {
        Group {
            if albums.isEmpty {
                EmptyStateView(
                    title: "Sin álbumes",
                    symbol: "square.stack",
                    description: "Los álbumes se agrupan localmente a partir de tus canciones guardadas."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(albums) { album in
                            albumCard(album)
                        }
                    }
                    .padding(.vertical, 16)
                    .responsiveHorizontalPadding()
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private func albumCard(_ album: LocalAlbum) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if let firstTrack = album.tracks.first {
                    onPlay(firstTrack.mediaItem)
                }
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    TrackArtwork(url: album.tracks.first?.mediaItem.thumbnailURL)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DiegoTheme.accent)
                        .background(Circle().fill(.black.opacity(0.4)))
                        .padding(8)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.name)
                    .font(.system(.body, design: .default, weight: .bold))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .lineLimit(1)

                Text("\(album.tracks.count) canciones")
                    .font(.caption)
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
