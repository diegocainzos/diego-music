import SwiftUI

enum LibrarySegment: String, CaseIterable, Identifiable {
    case playlists = "Playlists"
    case podcasts = "Podcasts"
    case songs = "Canciones"
    case albums = "Álbumes"
    case artists = "Artistas"
    case downloads = "Descargas"

    var id: String { rawValue }
}

typealias LibrarySection = LibrarySegment

/// Contenedor de la Biblioteca (Donda):
/// Segmentos: Playlists, Podcasts, Canciones, Álbumes, Artistas, Descargas.
struct LibraryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var library: LibraryStore
    let onPlay: (MediaItem) -> Void
    var onPlayQueue: (([MediaItem], Int) -> Void)? = nil
    var youtubeService: (any YouTubeDataServicing)? = nil
    var downloadManager: OfflineDownloadManager? = nil
    var resolver: (any AudioStreamResolving)? = nil
    var isOffline: Bool = false

    @SceneStorage("library.segment") private var selectedSegment: LibrarySegment = .playlists
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            chipsScrollView

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DiegoTheme.background)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(
                    playbackSettings: environment.playbackSettings,
                    library: library,
                    resolverConfigured: environment.resolverConfigured,
                    downloadManager: downloadManager ?? environment.downloadManager
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") {
                            showSettings = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cabecera Donda

    private var header: some View {
        ZStack {
            Text("BIBLIOTECA")
                .dondaTitle(size: 14)
                .tracking(6)
                .foregroundStyle(DiegoTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(DiegoTheme.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajustes")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Chips segmentados

    private var chipsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySegment.allCases) { seg in
                    let isSelected = selectedSegment == seg
                    Button {
                        selectedSegment = seg
                    } label: {
                        Text(seg.rawValue)
                            .dondaLabel()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? DiegoTheme.textPrimary : DiegoTheme.background)
                            .foregroundStyle(isSelected ? DiegoTheme.background : DiegoTheme.textPrimary)
                            .overlay(
                                Rectangle()
                                    .stroke(DiegoTheme.outline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Contenido por segmento

    @ViewBuilder
    private var content: some View {
        switch selectedSegment {
        case .playlists:
            PlaylistsView(
                library: library,
                onPlay: onPlay,
                onPlayQueue: onPlayQueue,
                youtubeService: youtubeService ?? environment.youtubeService
            )
        case .podcasts:
            PodcastsLibraryView(library: library)
        case .songs:
            SongsView(
                library: library,
                query: "",
                onPlay: onPlay,
                onPlayQueue: onPlayQueue,
                downloadManager: downloadManager ?? environment.downloadManager,
                resolver: resolver ?? environment.player.resolver,
                isOffline: isOffline
            )
        case .albums:
            AlbumsView(library: library, query: "", onPlay: onPlay)
        case .artists:
            ArtistsView(library: library, query: "", onPlay: onPlay)
        case .downloads:
            DownloadedView(downloadManager: downloadManager ?? environment.downloadManager, onPlay: onPlay, query: "")
        }
    }
}
