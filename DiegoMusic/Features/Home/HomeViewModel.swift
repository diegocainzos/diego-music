import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    enum FeedState: Equatable {
        case idle
        case loading
        case loaded(DiscoveryFeed)
        case empty
        case failed(message: String)
    }

    @Published private(set) var state: FeedState = .idle
    @Published private(set) var recommendations: [MediaItem] = []

    private var service: (any YouTubeDataServicing)?
    private var loadTask: Task<Void, Never>?

    init(service: any YouTubeDataServicing) {
        self.service = service
    }

    deinit { loadTask?.cancel() }

    /// Sustituye el servicio provisional (usado antes de conocer el real del
    /// entorno) y recarga si aún no había datos.
    func configure(service: any YouTubeDataServicing) {
        self.service = service
        if state == .idle { load() }
    }

    /// Best-effort: si el LLM o el resolutor fallan, la sección simplemente no aparece.
    func loadRecommendations(basedOn history: [MediaItem]) async {
        guard let service, !history.isEmpty else { return }
        if let items = try? await service.recommendations(basedOn: history) {
            recommendations = items
        }
    }

    func load() {
        guard let service else {
            state = .idle
            return
        }
        loadTask?.cancel()
        state = .loading
        loadTask = Task { [weak self, service] in
            do {
                let feed = try await service.discover()
                guard !Task.isCancelled else { return }
                self?.state = feed.novedades.isEmpty ? .empty : .loaded(feed)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription
                    ?? "No se pudo cargar el descubrimiento."
                self?.state = .failed(message: message)
            }
        }
    }
}
