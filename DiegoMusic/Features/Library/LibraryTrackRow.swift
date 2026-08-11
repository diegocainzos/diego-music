import SwiftUI

/// Fila reutilizable de una canción local: carátula, título, artista,
/// corazón (guardar/quitar) y reproducción. Mantiene 44pt de área táctil
/// y etiquetas accesibles.
struct LibraryTrackRow: View {
    let track: SavedTrack
    let isFavorite: Bool
    let onPlay: () -> Void
    let onFavorite: () -> Void

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
        }
        .padding(.vertical, 4)
    }
}