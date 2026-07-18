import Combine
import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var state: SearchPresentationState = .idle

    private let service: any YouTubeDataServicing
    private var searchTask: Task<Void, Never>?

    init(service: any YouTubeDataServicing) {
        self.service = service
    }

    deinit { searchTask?.cancel() }

    func search() {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            state = .empty
            return
        }
        searchTask?.cancel()
        state = .loading
        searchTask = Task { [weak self, service] in
            do {
                let page = try await service.search(query: normalized, pageToken: nil)
                guard !Task.isCancelled else { return }
                self?.state = page.items.isEmpty ? .empty : .loaded(page.items)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription ?? "No se pudo completar la búsqueda."
                self?.state = .failed(message: message)
            }
        }
    }
}
