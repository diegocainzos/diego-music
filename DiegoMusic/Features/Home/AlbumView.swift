import SwiftUI

@MainActor
final class AlbumViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(Album)
        case failed(message: String)
    }

    @Published private(set) var state: State = .loading

    private let playlistID: String
    private let service: any YouTubeDataServicing
    private var task: Task<Void, Never>?

    init(playlistID: String, service: any YouTubeDataServicing) {
        self.playlistID = playlistID
        self.service = service
    }

    deinit { task?.cancel() }

    func load() {
        task?.cancel()
        if case .loading = state {} else { state = .loading }
        task = Task { [weak self, service, playlistID] in
            do {
                let album = try await service.album(byPlaylistID: playlistID)
                guard !Task.isCancelled else { return }
                self?.state = .loaded(album)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar el álbum."
                self?.state = .failed(message: message)
            }
        }
    }
}

struct AlbumView: View {
    let playlistID: String
    @StateObject private var model: AlbumViewModel
    let onPlay: (MediaItem) -> Void

    init(playlistID: String, service: any YouTubeDataServicing, onPlay: @escaping (MediaItem) -> Void) {
        self.playlistID = playlistID
        self.onPlay = onPlay
        _model = StateObject(wrappedValue: AlbumViewModel(playlistID: playlistID, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(eyebrow: "Álbum / Lista", title: albumTitle, color: DiegoTheme.accent)

                switch model.state {
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small).tint(DiegoTheme.accent)
                        Text("Cargando pistas…").font(.callout).foregroundStyle(DiegoTheme.textSecondary)
                    }
                case let .failed(message):
                    HStack(spacing: 10) {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(DiegoTheme.textSecondary)
                        Button("Reintentar") { model.load() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                case let .loaded(album):
                    header(album)
                    tracks(album.tracks)
                }
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .task { model.load() }
    }

    private var albumTitle: String {
        if case let .loaded(album) = model.state { return album.title }
        return "Álbum"
    }

    private func header(_ album: Album) -> some View {
        HStack(spacing: 18) {
            TrackArtwork(url: album.thumbnailURL)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(album.title).font(.title.bold()).foregroundStyle(DiegoTheme.textPrimary)
                if let channel = album.channelTitle {
                    Text(channel).font(.subheadline).foregroundStyle(DiegoTheme.textSecondary)
                }
                Text("\(album.tracks.count) pistas").font(.caption).foregroundStyle(DiegoTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalCard()
    }

    private func tracks(_ items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lista de pistas").font(.title3.bold()).foregroundStyle(DiegoTheme.textPrimary)
            if items.isEmpty {
                Text("Este álbum no tiene pistas reproducibles.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button { onPlay(item) } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(DiegoTheme.textSecondary)
                                    .frame(width: 24, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.headline).lineLimit(1).foregroundStyle(DiegoTheme.textPrimary)
                                    Text(item.channelTitle).font(.caption).foregroundStyle(DiegoTheme.textSecondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "play.fill").foregroundStyle(DiegoTheme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
