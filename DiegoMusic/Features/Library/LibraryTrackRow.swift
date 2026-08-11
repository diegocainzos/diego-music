import SwiftUI

/// Fila reutilizable de una canción local: carátula, título, artista,
/// corazón (guardar/quitar), descarga offline y reproducción.
struct LibraryTrackRow: View {
    let track: SavedTrack
    let isFavorite: Bool
    let onPlay: () -> Void
    let onFavorite: () -> Void
    var downloadManager: OfflineDownloadManager? = nil
    var resolver: (any AudioStreamResolving)? = nil
    // Estado de red para atenuar filas no disponibles offline
    var isOffline: Bool = false

    private var isDownloaded: Bool {
        downloadManager?.isDownloaded(videoID: track.videoID) ?? false
    }

    private var isUnavailableOffline: Bool {
        isOffline && !isDownloaded
    }

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
                        Text(track.channelTitle)
                            .font(.caption)
                            .foregroundStyle(DiegoTheme.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isUnavailableOffline)
            .accessibilityLabel("Reproducir \(track.title)")

            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.body)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(isFavorite ? DiegoTheme.accent : DiegoTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Quitar de la biblioteca" : "Guardar en la biblioteca")
            .accessibilityValue(isFavorite ? "Guardada" : "Sin guardar")

            // Botón de descarga offline
            if let dm = downloadManager, let res = resolver {
                DownloadButton(item: track.mediaItem, downloadManager: dm, resolver: res)
            }
        }
        .padding(.vertical, 4)
        .opacity(isUnavailableOffline ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isUnavailableOffline)
        .overlay(alignment: .center) {
            if isUnavailableOffline {
                // Mensaje emergente al tocar (solo visual; el hit-test está desactivado)
                EmptyView()
            }
        }
    }
}