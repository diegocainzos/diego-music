import Combine
import Foundation

@MainActor
final class PlaybackQueue: ObservableObject {
    @Published private(set) var items: [MediaItem]
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isShuffled = false

    private var shuffleOrder: [MediaItem.ID] = []
    private var shufflePosition = 0

    init(items: [MediaItem] = [], currentIndex: Int? = nil) {
        self.items = items
        if let currentIndex, items.indices.contains(currentIndex) {
            self.currentIndex = currentIndex
        } else {
            self.currentIndex = items.isEmpty ? nil : 0
        }
    }

    var current: MediaItem? {
        guard let currentIndex, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var canAdvance: Bool {
        if isShuffled {
            return shufflePosition + 1 < shuffleOrder.count
        }
        guard let currentIndex else { return false }
        return currentIndex + 1 < items.count
    }

    var canRetreat: Bool {
        if isShuffled {
            return shufflePosition > 0
        }
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    /// Activa/desactiva el modo shuffle conservando la pista activa.
    /// Al desactivar se restaura el orden original de `items` y la pista activa.
    func setShuffle(_ enabled: Bool) {
        guard enabled != isShuffled else { return }
        isShuffled = enabled
        if enabled {
            reshuffleForCurrent()
        } else {
            shuffleOrder = []
            shufflePosition = 0
        }
    }

    private func reshuffleForCurrent() {
        guard !items.isEmpty else { return }
        let currentID = current?.id
        var ids = items.map(\.id)
        ids.shuffle()
        shuffleOrder = ids
        if let currentID, let position = shuffleOrder.firstIndex(of: currentID) {
            shufflePosition = position
        } else {
            shufflePosition = 0
        }
        // currentIndex sigue apuntando a la pista activa dentro de `items`.
    }

    private func rebuildAfterMutation() {
        if isShuffled { reshuffleForCurrent() }
    }

    func play(_ item: MediaItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            currentIndex = index
        } else {
            items.append(item)
            currentIndex = items.count - 1
        }
        rebuildAfterMutation()
    }

    func enqueue(_ item: MediaItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        if currentIndex == nil { currentIndex = 0 }
        rebuildAfterMutation()
    }

    /// Añade una pista inmediatamente después de la pista en reproducción actual (posición 1 de siguientes).
    func enqueueNext(_ item: MediaItem) {
        if current?.id == item.id { return }

        if let existingIndex = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: existingIndex)
            if let currentIdx = currentIndex, existingIndex < currentIdx {
                currentIndex = currentIdx - 1
            }
        }

        if let currentIdx = currentIndex, currentIdx < items.count {
            let targetIndex = currentIdx + 1
            items.insert(item, at: targetIndex)
        } else {
            items.append(item)
            if currentIndex == nil { currentIndex = 0 }
        }
        rebuildAfterMutation()
    }

    /// Añade una lista de pistas al final de la cola (para radio automática o álbumes) evitando duplicar elementos.
    func enqueueBatch(_ newItems: [MediaItem]) {
        let existingIDs = Set(items.map(\.id))
        let filtered = newItems.filter { !existingIDs.contains($0.id) }
        guard !filtered.isEmpty else { return }
        items.append(contentsOf: filtered)
        if currentIndex == nil { currentIndex = 0 }
        rebuildAfterMutation()
    }

    @discardableResult
    func advance() -> MediaItem? {
        if isShuffled {
            guard shufflePosition + 1 < shuffleOrder.count else { return nil }
            shufflePosition += 1
            if let index = items.firstIndex(where: { $0.id == shuffleOrder[shufflePosition] }) {
                currentIndex = index
            }
            return current
        }
        guard canAdvance, let currentIndex else { return nil }
        self.currentIndex = currentIndex + 1
        return current
    }

    @discardableResult
    func retreat() -> MediaItem? {
        if isShuffled {
            guard shufflePosition > 0 else { return nil }
            shufflePosition -= 1
            if let index = items.firstIndex(where: { $0.id == shuffleOrder[shufflePosition] }) {
                currentIndex = index
            }
            return current
        }
        guard canRetreat, let currentIndex else { return nil }
        self.currentIndex = currentIndex - 1
        return current
    }

    /// Reinicia la cola desde su primera posición (para repeat all / radio).
    @discardableResult
    func resetToStart() -> MediaItem? {
        guard !items.isEmpty else { return nil }
        currentIndex = 0
        if isShuffled {
            shufflePosition = 0
            if let first = items.first, let position = shuffleOrder.firstIndex(of: first.id) {
                shufflePosition = position
                if let index = items.firstIndex(where: { $0.id == shuffleOrder[shufflePosition] }) {
                    currentIndex = index
                }
            }
        }
        return current
    }

    func remove(id: MediaItem.ID) {
        guard let removedIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let currentID = current?.id
        items.remove(at: removedIndex)

        guard !items.isEmpty else {
            currentIndex = nil
            shuffleOrder = []
            shufflePosition = 0
            return
        }
        if let currentID, let relocated = items.firstIndex(where: { $0.id == currentID }) {
            currentIndex = relocated
        } else {
            currentIndex = min(removedIndex, items.count - 1)
        }
        rebuildAfterMutation()
    }

    func move(from source: IndexSet, to destination: Int) {
        let currentID = current?.id
        let orderedSource = source.sorted()
        let moving = orderedSource.map { items[$0] }
        for index in orderedSource.reversed() { items.remove(at: index) }
        let removedBeforeDestination = orderedSource.filter { $0 < destination }.count
        let insertion = max(0, min(destination - removedBeforeDestination, items.count))
        items.insert(contentsOf: moving, at: insertion)
        if let currentID { currentIndex = items.firstIndex(where: { $0.id == currentID }) }
        rebuildAfterMutation()
    }

    func move(id: MediaItem.ID, by offset: Int) {
        guard let source = items.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard items.indices.contains(destination) else { return }
        let currentID = current?.id
        items.swapAt(source, destination)
        if let currentID { currentIndex = items.firstIndex(where: { $0.id == currentID }) }
        rebuildAfterMutation()
    }

    func clear() {
        items.removeAll()
        currentIndex = nil
        shuffleOrder = []
        shufflePosition = 0
        isShuffled = false
    }
}
