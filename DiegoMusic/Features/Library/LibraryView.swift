import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case songs = "Canciones"
    case albums = "Álbumes"
    case artists = "Artistas"
    case lists = "Listas"
    case downloads = "Descargados"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .songs: return "music.note"
        case .albums: return "square.stack"
        case .artists: return "music.mic"
        case .lists: return "music.note.list"
        case .downloads: return "arrow.down.circle.fill"
        }
    }
}

/// Contenedor de la Biblioteca estilo Apple Music Web:
/// Sub-pestañas Canciones / Álbumes / Artistas / Listas / Descargados, búsqueda local instantánea.
struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void
    var downloadManager: OfflineDownloadManager? = nil
    var resolver: (any AudioStreamResolving)? = nil
    var isOffline: Bool = false

    @State private var section: LibrarySection = .songs
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(eyebrow: "Tu colección", title: "Biblioteca", color: DiegoTheme.accent)
                .responsiveHorizontalPadding()
                .padding(.top, 14)

            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .accessibilityHidden(true)

                    TextField("Buscar en tu biblioteca…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .autocorrectionDisabled()

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(DiegoTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(DiegoTheme.surface)
                .clipShape(Capsule())
                .overlay { Capsule().stroke(DiegoTheme.textPrimary.opacity(0.12), lineWidth: 1) }
            }
            .responsiveHorizontalPadding()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LibrarySection.allCases) { sec in
                        LibrarySectionChip(
                            section: sec,
                            isSelected: section == sec,
                            hasDownloads: sec == .downloads
                                ? !(downloadManager?.downloadedTracks.isEmpty ?? true)
                                : false
                        ) {
                            section = sec
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .songs:
            SongsView(
                library: library,
                query: query,
                onPlay: onPlay,
                downloadManager: downloadManager,
                resolver: resolver,
                isOffline: isOffline
            )
        case .albums:
            AlbumsView(library: library, query: query, onPlay: onPlay)
        case .artists:
            ArtistsView(library: library, query: query, onPlay: onPlay)
        case .lists:
            ListaView(library: library, query: query, onPlay: onPlay)
                .responsiveHorizontalPadding()
        case .downloads:
            if let dm = downloadManager {
                DownloadedView(downloadManager: dm, onPlay: onPlay, query: query)
                    .responsiveHorizontalPadding()
            } else {
                EmptyStateView(
                    title: "Descargas no disponibles",
                    symbol: "arrow.down.circle",
                    description: "El gestor de descargas no está configurado."
                )
            }
        }
    }
}

// MARK: - Chip de sección

private struct LibrarySectionChip: View {
    let section: LibrarySection
    let isSelected: Bool
    let hasDownloads: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: section.symbol)
                    .font(.caption.weight(.semibold))
                Text(section.rawValue)
                    .font(.subheadline.weight(.semibold))
                if section == .downloads && hasDownloads {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(DiegoTheme.green)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? DiegoTheme.accent : DiegoTheme.surface)
            .foregroundStyle(isSelected ? Color.white : DiegoTheme.textSecondary)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule().stroke(DiegoTheme.textPrimary.opacity(0.12), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}
