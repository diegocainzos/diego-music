import Combine
import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var activeScope: SearchScope = .todo
    @Published private(set) var recentQueries: [String] = []
    @Published private(set) var state: SearchPresentationState = .idle

    private let service: any YouTubeDataServicing
    private let history: SearchHistory
    private var searchTask: Task<Void, Never>?
    private var rawItems: [MediaItem] = []

    init(service: any YouTubeDataServicing, libraryStore: LibraryStore) {
        self.service = service
        self.history = SearchHistory(libraryStore: libraryStore)
        self.recentQueries = history.recentQueries
    }

    deinit {
        searchTask?.cancel()
    }

    /// Indica si YouTube devolvió resultados sin filtrar; permite distinguir
    /// un vacío por ámbito de un vacío real de catálogo.
    var hasRawResults: Bool { !rawItems.isEmpty }

    /// Cambia el ámbito y re-filtra la presentación SIN lanzar otra petición.
    func changeScope(_ scope: SearchScope) {
        guard scope != activeScope else { return }
        activeScope = scope
        applyScope()
    }

    /// Limpia la búsqueda activa devolviendo la vista al estado inicial.
    func clearSearch() {
        searchTask?.cancel()
        rawItems = []
        state = .idle
    }

    /// Búsqueda explícita (botón Buscar / submit / selección desde historial).
    func search() {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            clearSearch()
            return
        }
        runSearch(normalized)
    }

    /// Rellena el campo con una consulta reciente y ejecuta la búsqueda.
    func selectRecent(_ recent: String) {
        query = recent
        search()
    }

    private func runSearch(_ normalized: String) {
        searchTask?.cancel()
        state = .loading
        searchTask = Task { [weak self, service] in
            do {
                let page = try await service.search(query: normalized, pageToken: nil)
                guard !Task.isCancelled else { return }
                self?.history.record(normalized)
                self?.recentQueries = self?.history.recentQueries ?? []
                self?.rawItems = page.items
                self?.applyScope()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription
                    ?? "No se pudo completar la búsqueda."
                self?.state = .failed(message: message)
            }
        }
    }

    private func applyScope() {
        let filtered = rawItems.filter { activeScope.matches($0, query: query) }
        state = filtered.isEmpty ? .empty : .loaded(filtered)
    }
}
