import SwiftUI

@MainActor
final class ArtistViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(ArtistDetail)
        case failed(message: String)
    }

    @Published private(set) var state: State = .loading

    private let artistID: String
    private let service: any YouTubeDataServicing
    private var task: Task<Void, Never>?

    init(artistID: String, service: any YouTubeDataServicing) {
        self.artistID = artistID
        self.service = service
    }

    deinit { task?.cancel() }

    func load() {
        task?.cancel()
        if case .loading = state {} else { state = .loading }
        task = Task { [weak self, service, artistID] in
            do {
                let detail = try await service.artist(byChannelID: artistID)
                guard !Task.isCancelled else { return }
                self?.state = .loaded(detail)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar el artista."
                self?.state = .failed(message: message)
            }
        }
    }
}

struct ArtistView: View {
    let artistID: String
    let artistTitle: String
    @StateObject private var model: ArtistViewModel
    let onPlay: (MediaItem) -> Void

    init(artistID: String, artistTitle: String, service: any YouTubeDataServicing, onPlay: @escaping (MediaItem) -> Void) {
        self.artistID = artistID
        self.artistTitle = artistTitle
        self.onPlay = onPlay
        _model = StateObject(wrappedValue: ArtistViewModel(artistID: artistID, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(eyebrow: "Perfil", title: artistTitle, color: DiegoTheme.accent)

                switch model.state {
                case .loading:
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small).tint(DiegoTheme.accent)
                        Text("Cargando artista…").font(.callout).foregroundStyle(DiegoTheme.textSecondary)
                    }
                case let .failed(message):
                    HStack(spacing: 10) {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(DiegoTheme.textSecondary)
                        Button("Reintentar") { model.load() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                case let .loaded(detail):
                    profile(detail)
                    section("Top tracks", items: detail.topTracks)
                    section("Relacionados", items: detail.related)
                }
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .task { model.load() }
    }

    private func profile(_ detail: ArtistDetail) -> some View {
        HStack(spacing: 18) {
            TrackArtwork(url: detail.artist.thumbnailURL)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(detail.artist.title).font(.title.bold()).foregroundStyle(DiegoTheme.textPrimary)
                if let bio = detail.artist.bio, !bio.isEmpty {
                    Text(bio).font(.callout).foregroundStyle(DiegoTheme.textSecondary).lineLimit(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalCard()
    }

    private func section(_ title: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold()).foregroundStyle(DiegoTheme.textPrimary)
            if items.isEmpty {
                Text("Sin resultados disponibles.")
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(items) { item in
                        Button { onPlay(item) } label: {
                            HStack(spacing: 12) {
                                TrackArtwork(url: item.thumbnailURL)
                                    .frame(width: 46, height: 46)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
