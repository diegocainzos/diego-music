import SwiftUI

/// Vista de la sección "Descargados" en la Biblioteca.
/// Muestra las pistas almacenadas localmente en el dispositivo.
struct DownloadedView: View {
    @ObservedObject var downloadManager: OfflineDownloadManager
    let onPlay: (MediaItem) -> Void
    var query: String = ""

    private var filtered: [DownloadedTrack] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return downloadManager.downloadedTracks
        }
        let q = query.lowercased()
        return downloadManager.downloadedTracks.filter {
            $0.title.lowercased().contains(q) || $0.channelTitle.lowercased().contains(q)
        }
    }

    var body: some View {
        if downloadManager.downloadedTracks.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { track in
                        DownloadedTrackRow(
                            track: track,
                            downloadManager: downloadManager,
                            onPlay: { onPlay(track.mediaItem) }
                        )
                        Divider()
                            .background(DiegoTheme.textPrimary.opacity(0.06))
                            .padding(.leading, 76)
                    }
                }
                .padding(.bottom, 120)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(DiegoTheme.textSecondary)
            Text("Sin descargas")
                .font(.title3.bold())
                .foregroundStyle(DiegoTheme.textPrimary)
            Text("Las canciones, álbumes y playlists que descargues aparecerán aquí para escucharlas sin conexión.")
                .font(.callout)
                .foregroundStyle(DiegoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Fila de pista descargada

private struct DownloadedTrackRow: View {
    let track: DownloadedTrack
    @ObservedObject var downloadManager: OfflineDownloadManager
    let onPlay: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    TrackArtwork(url: track.mediaItem.thumbnailURL)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundStyle(DiegoTheme.textPrimary)

                        HStack(spacing: 6) {
                            Text(track.channelTitle)
                                .font(.caption)
                                .foregroundStyle(DiegoTheme.textSecondary)
                                .lineLimit(1)

                            Text("·")
                                .font(.caption)
                                .foregroundStyle(DiegoTheme.textSecondary)

                            Text(track.formattedSize)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(DiegoTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reproducir \(track.title)")

            // Badge descargado + acción eliminar
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.body)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(DiegoTheme.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Eliminar descarga de \(track.title)")
            .confirmationDialog(
                "Eliminar descarga",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive) {
                    try? downloadManager.removeDownload(videoID: track.videoID)
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se borrará \"\(track.title)\" del almacenamiento local.")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
