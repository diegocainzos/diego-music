import SwiftUI

/// Canciones de la biblioteca: tabla estilo Apple Music Web con soporte
/// de descarga offline e indicador de estado sin conexión.
struct SongsView: View {
    @ObservedObject var library: LibraryStore
    let query: String
    let onPlay: (MediaItem) -> Void
    var onPlayQueue: (([MediaItem], Int) -> Void)? = nil
    var downloadManager: OfflineDownloadManager? = nil
    var resolver: (any AudioStreamResolving)? = nil
    var isOffline: Bool = false

    @State private var showOnlyDownloaded = false

    private var filtered: [SavedTrack] {
        let base: [SavedTrack]
        if showOnlyDownloaded, let dm = downloadManager {
            base = library.songs.filter { dm.isDownloaded(videoID: $0.videoID) }
        } else {
            base = library.songs
        }
        return base.filter { $0.matches(query: query) }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                EmptyStateView(
                    title: showOnlyDownloaded ? "Sin descargas" : "Sin canciones",
                    symbol: showOnlyDownloaded ? "arrow.down.circle" : "music.note",
                    description: showOnlyDownloaded
                        ? "Descarga canciones para escucharlas sin conexión."
                        : (query.isEmpty
                            ? "Guarda canciones desde Búsqueda para verlas aquí."
                            : "Ninguna canción coincide con tu búsqueda.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Toggle "Solo descargados"
                        if downloadManager != nil {
                            Toggle(isOn: $showOnlyDownloaded) {
                                Label("Solo descargados", systemImage: "arrow.down.circle.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(showOnlyDownloaded ? DiegoTheme.green : DiegoTheme.textSecondary)
                            }
                            .toggleStyle(.switch)
                            .tint(DiegoTheme.green)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 12)
                        }

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
        let unavailableOffline = isOffline && !(downloadManager?.isDownloaded(videoID: track.videoID) ?? false)

        return HStack(spacing: 12) {
            Button {
                if let onPlayQueue {
                    onPlayQueue(filtered.map(\.mediaItem), index - 1)
                } else {
                    onPlay(track.mediaItem)
                }
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
            .disabled(unavailableOffline)

            HStack(spacing: 4) {
                // Botón de descarga offline
                if let dm = downloadManager, let res = resolver {
                    DownloadButton(item: track.mediaItem, downloadManager: dm, resolver: res)
                }

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
                    if let dm = downloadManager, let res = resolver {
                        if dm.isDownloaded(videoID: track.videoID) {
                            Button(role: .destructive) {
                                try? dm.removeDownload(videoID: track.videoID)
                            } label: {
                                Label("Eliminar descarga", systemImage: "trash")
                            }
                        } else {
                            Button {
                                dm.enqueue(track.mediaItem, resolver: res)
                            } label: {
                                Label("Descargar", systemImage: "arrow.down.circle")
                            }
                        }
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
        .opacity(unavailableOffline ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: unavailableOffline)
    }
}
