import SwiftUI

struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(eyebrow: "Solo en tu dispositivo", title: "Biblioteca", color: DiegoTheme.accent)
                .padding(.horizontal, 28)
                .padding(.top, 28)

            if library.favorites.isEmpty {
                EmptyStateView(
                    title: "Aún no hay favoritos",
                    symbol: "heart",
                    description: "Guarda resultados desde Búsqueda para construir tu colección."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(library.favorites) { track in
                        Button { onPlay(track.mediaItem) } label: {
                            HStack(spacing: 14) {
                                TrackArtwork(url: track.mediaItem.thumbnailURL).frame(width: 54, height: 54)
                                VStack(alignment: .leading) {
                                    Text(track.title).font(.headline)
                                    Text(track.channelTitle).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.fill").foregroundStyle(DiegoTheme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { try? library.deleteFavorite(library.favorites[index]) }
    }
}
