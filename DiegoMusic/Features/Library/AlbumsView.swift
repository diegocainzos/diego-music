import SwiftUI

import SwiftUI

/// Álbumes de la biblioteca: rejilla de tarjetas cuadradas al estilo Apple Music Web.
/// Muestra álbumes guardados explícitamente y álbumes locales derivados.
struct AlbumsView: View {
    @ObservedObject var library: LibraryStore
    let query: String
    let onPlay: (MediaItem) -> Void

    @EnvironmentObject private var navState: NavigationState

    private var savedAlbums: [SavedAlbum] {
        library.savedAlbums.filter { $0.matches(query: query) }
    }

    private var localAlbums: [LocalAlbum] {
        library.albums.filter { album in
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            return album.name.matches(query: query) || album.tracks.contains { $0.matches(query: query) }
        }
    }

    private var isEmpty: Bool {
        savedAlbums.isEmpty && localAlbums.isEmpty
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]

    var body: some View {
        Group {
            if isEmpty {
                EmptyStateView(
                    title: "Sin álbumes",
                    symbol: "square.stack",
                    description: "Guarda álbumes desde el reproductor o la ficha del álbum para tenerlos aquí."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        if !savedAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Álbumes guardados")
                                    .font(.title2.bold())
                                    .foregroundStyle(DiegoTheme.textPrimary)

                                LazyVGrid(columns: columns, spacing: 24) {
                                    ForEach(savedAlbums) { album in
                                        savedAlbumCard(album)
                                    }
                                }
                            }
                        }

                        if !localAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                if !savedAlbums.isEmpty {
                                    Text("Agrupaciones locales")
                                        .font(.title2.bold())
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                }

                                LazyVGrid(columns: columns, spacing: 24) {
                                    ForEach(localAlbums) { album in
                                        localAlbumCard(album)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .responsiveHorizontalPadding()
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private func savedAlbumCard(_ album: SavedAlbum) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                TrackArtwork(url: album.thumbnailURL)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                Button {
                    onPlay(MediaItem(
                        id: album.id,
                        title: album.title,
                        channelTitle: album.channelTitle ?? "Álbum",
                        thumbnailURL: album.thumbnailURL
                    ))
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DiegoTheme.accent)
                        .background(Circle().fill(.black.opacity(0.4)))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navState.navigate(to: .albumDetail(id: album.id, title: album.title))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(.body, design: .default, weight: .bold))
                    .foregroundStyle(DiegoTheme.textPrimary)
                    .lineLimit(1)

                if let channel = album.channelTitle {
                    Text(channel)
                        .font(.caption)
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navState.navigate(to: .albumDetail(id: album.id, title: album.title))
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                try? library.deleteSavedAlbum(id: album.id)
            } label: {
                Label("Eliminar de la biblioteca", systemImage: "trash")
            }
        }
    }

    private func localAlbumCard(_ album: LocalAlbum) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                TrackArtwork(url: album.tracks.first?.mediaItem.thumbnailURL)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)

                Button {
                    if let firstTrack = album.tracks.first {
                        onPlay(firstTrack.mediaItem)
                    }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DiegoTheme.accent)
                        .background(Circle().fill(.black.opacity(0.4)))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navState.navigate(to: .albumDetail(id: album.name, title: album.name))
            }

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
            .contentShape(Rectangle())
            .onTapGesture {
                navState.navigate(to: .albumDetail(id: album.name, title: album.name))
            }
        }
    }
}
