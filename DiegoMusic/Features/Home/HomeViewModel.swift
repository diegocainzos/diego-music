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
    @Published private(set) var quickPicks: [MediaItem] = []

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

    /// Selecciones rápidas: Mix de la última pista escuchada, sin la semilla. Best-effort:
    /// sin historial, fallo o lista vacía la sección simplemente no aparece (sin estado de error).
    func loadQuickPicks(seed: MediaItem?) async {
        guard let service, let seed else {
            quickPicks = []
            return
        }
        let mix = (try? await service.radio(seed: seed.id)) ?? []
        quickPicks = Array(mix.filter { $0.id != seed.id }.prefix(20))
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
