import SwiftUI

/// Canciones de la biblioteca: tabla estilo Apple Music Web con cabecera (#, Título, Artista, Menú).
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
                ScrollView {
                    VStack(spacing: 0) {
                        tableHeader
                            .padding(.bottom, 8)

                        Divider()
                            .overlay(Color.white.opacity(0.1))
                            .padding(.bottom, 8)

                        LazyVStack(spacing: 4) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, track in
                                songRow(track: track, index: index + 1)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .responsiveHorizontalPadding()
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("#")
                .font(.caption.weight(.bold))
                .foregroundStyle(DiegoTheme.textSecondary)
                .frame(width: 28, alignment: .center)

            Text("TÍTULO")
                .font(.caption.weight(.bold))
                .foregroundStyle(DiegoTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("ARTISTA")
                .font(.caption.weight(.bold))
                .foregroundStyle(DiegoTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Image(systemName: "ellipsis")
                .font(.caption.weight(.bold))
                .foregroundStyle(DiegoTheme.textSecondary)
                .frame(width: 44, alignment: .center)
        }
        .padding(.horizontal, 8)
    }

    private func songRow(track: SavedTrack, index: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                onPlay(track.mediaItem)
            } label: {
                HStack(spacing: 12) {
                    Text("\(index)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .frame(width: 28, alignment: .center)

                    TrackArtwork(url: track.mediaItem.thumbnailURL)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(DiegoTheme.textPrimary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(track.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Button {
                    try? library.toggleFavorite(track.mediaItem)
                } label: {
                    Image(systemName: library.isFavorite(track.mediaItem) ? "heart.fill" : "heart")
                        .font(.body)
                        .foregroundStyle(library.isFavorite(track.mediaItem) ? DiegoTheme.accent : DiegoTheme.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Menu {
                    Button {
                        onPlay(track.mediaItem)
                    } label: {
                        Label("Reproducir", systemImage: "play.fill")
                    }
                    if !library.playlists.isEmpty {
                        Menu {
                            ForEach(library.playlists) { playlist in
                                Button(playlist.name) {
                                    try? library.add(track.mediaItem, to: playlist)
                                }
                            }
                        } label: {
                            Label("Añadir a playlist", systemImage: "text.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(DiegoTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
