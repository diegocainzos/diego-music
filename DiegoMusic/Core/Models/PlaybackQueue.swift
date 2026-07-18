import Combine
import Foundation

@MainActor
final class PlaybackQueue: ObservableObject {
    @Published private(set) var items: [MediaItem]
    @Published private(set) var currentIndex: Int?

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
        guard let currentIndex else { return false }
        return currentIndex + 1 < items.count
    }

    var canRetreat: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    func play(_ item: MediaItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            currentIndex = index
        } else {
            items.append(item)
            currentIndex = items.count - 1
        }
    }

    func enqueue(_ item: MediaItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        if currentIndex == nil { currentIndex = 0 }
    }

    @discardableResult
    func advance() -> MediaItem? {
        guard canAdvance, let currentIndex else { return nil }
        self.currentIndex = currentIndex + 1
        return current
    }

    @discardableResult
    func retreat() -> MediaItem? {
        guard canRetreat, let currentIndex else { return nil }
        self.currentIndex = currentIndex - 1
        return current
    }

    func remove(id: MediaItem.ID) {
        guard let removedIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let currentID = current?.id
        items.remove(at: removedIndex)

        guard !items.isEmpty else {
            currentIndex = nil
            return
        }
        if let currentID, let relocated = items.firstIndex(where: { $0.id == currentID }) {
            currentIndex = relocated
        } else {
            currentIndex = min(removedIndex, items.count - 1)
        }
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
    }

    func move(id: MediaItem.ID, by offset: Int) {
        guard let source = items.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard items.indices.contains(destination) else { return }
        let currentID = current?.id
        items.swapAt(source, destination)
        if let currentID { currentIndex = items.firstIndex(where: { $0.id == currentID }) }
    }

    func clear() {
        items.removeAll()
        currentIndex = nil
    }
}
