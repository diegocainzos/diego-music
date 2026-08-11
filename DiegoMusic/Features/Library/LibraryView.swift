import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case songs = "Canciones"
    case albums = "Álbumes"
    case artists = "Artistas"
    case lists = "Listas"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .songs: return "music.note"
        case .albums: return "square.stack"
        case .artists: return "music.mic"
        case .lists: return "music.note.list"
        }
    }
}

/// Contenedor de la Biblioteca estilo Apple Music Web:
/// Sub-pestañas Canciones / Álbumes / Artistas / Listas, búsqueda local instantánea.
struct LibraryView: View {
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void

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

            Picker("Sección", selection: $section) {
                ForEach(LibrarySection.allCases) { sec in
                    Label(sec.rawValue, systemImage: sec.symbol).tag(sec)
                }
            }
            .pickerStyle(.segmented)
            .responsiveHorizontalPadding()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .songs:
            SongsView(library: library, query: query, onPlay: onPlay)
        case .albums:
            AlbumsView(library: library, query: query, onPlay: onPlay)
        case .artists:
            ArtistsView(library: library, query: query, onPlay: onPlay)
        case .lists:
            ListaView(library: library, query: query, onPlay: onPlay)
                .responsiveHorizontalPadding()
        }
    }
}
