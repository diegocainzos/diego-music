import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    private static let storageKey = "home.quickPicks"

    @Published private(set) var quickPicks: [MediaItem]

    private var service: (any YouTubeDataServicing)?
    private let defaults: UserDefaults
    private var refreshGeneration = 0

    init(service: any YouTubeDataServicing, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        quickPicks = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([MediaItem].self, from: $0) } ?? []
    }

    /// Sustituye el servicio provisional (usado antes de conocer el real del entorno).
    func configure(service: any YouTubeDataServicing) {
        self.service = service
    }

    /// Selecciones rápidas: mezcla de los Mix de hasta 3 semillas del historial. Best-effort: sin
    /// semillas, sin Mix o con fallos se conserva la lista previa (nunca queda vacía por un refresco).
    func refreshQuickPicks(history: [MediaItem]) async {
        guard let service else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        var rng = SystemRandomNumberGenerator()
        let seeds = HomeLogic.quickPickSeeds(history, using: &rng)
        guard !seeds.isEmpty else { return }

        let mixes: [[MediaItem]] = await withTaskGroup(of: (Int, [MediaItem]).self) { group in
            for (index, seed) in seeds.enumerated() {
                group.addTask { (index, (try? await service.radio(seed: seed)) ?? []) }
            }
            var ordered = Array(repeating: [MediaItem](), count: seeds.count)
            for await (index, items) in group { ordered[index] = items }
            return ordered
        }

        guard generation == refreshGeneration, !Task.isCancelled else { return }
        let merged = HomeLogic.mergeMixes(seeds: seeds, mixes: mixes)
        guard !merged.isEmpty else { return }
        quickPicks = merged
        defaults.set(try? JSONEncoder().encode(merged), forKey: Self.storageKey)
    }
}
