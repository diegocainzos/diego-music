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
    private var debounceTask: Task<Void, Never>?
    private var rawItems: [MediaItem] = []

    init(service: any YouTubeDataServicing, libraryStore: LibraryStore) {
        self.service = service
        self.history = SearchHistory(libraryStore: libraryStore)
        self.recentQueries = history.recentQueries
    }

    deinit {
        searchTask?.cancel()
        debounceTask?.cancel()
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

    /// Llamado por la vista al cambiar la consulta; aplica un pequeño debounce
    /// y cancela la tarea anterior.
    func queryDidChange() {
        debounceTask?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            searchTask?.cancel()
            rawItems = []
            state = .idle
            return
        }
        state = .loading
        let taskQuery = normalized
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.runSearch(taskQuery)
        }
    }

    /// Búsqueda inmediata (botón Buscar / submit / selección desde historial).
    func search() {
        debounceTask?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            searchTask?.cancel()
            rawItems = []
            state = .empty
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
