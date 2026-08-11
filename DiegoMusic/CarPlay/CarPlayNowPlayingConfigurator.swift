import CarPlay
import Combine
import Foundation
import MediaPlayer

#if os(iOS)
/// Sincroniza el estado observable del `AudioPlayerCoordinator`/`PlaybackQueue`
/// con las plantillas CarPlay, sin duplicar la fuente de verdad: los metadatos de
/// Now Playing siguen publicándose en `MPNowPlayingInfoCenter` por el coordinador,
/// y aquí solo se refresca la plantilla con ellos en el actor principal.
@MainActor
final class CarPlayNowPlayingConfigurator: NSObject, CPNowPlayingTemplateObserver {

    private let player: AudioPlayerCoordinator
    private let queue: PlaybackQueue
    private var cancellables: Set<AnyCancellable> = []

    /// Invocado al pulsar "Cola" en el Now Playing de CarPlay.
    var onUpNext: (() -> Void)?

    init(player: AudioPlayerCoordinator, queue: PlaybackQueue) {
        self.player = player
        self.queue = queue
        super.init()
        observe()
    }

    private func observe() {
        // Combina los cambios observables que afectan a Now Playing/cola.
        let state = player.$playbackState.combineLatest(player.$currentTime)
        state.combineLatest(queue.$items)
            .sink { [weak self] _, _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    /// Refresca la plantilla Now Playing con la información que el coordinador ya
    /// publicó en `MPNowPlayingInfoCenter` (fuente única de verdad).
    func refresh() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        CPNowPlayingTemplate.shared.updateNowPlayingInfo(info)
    }

    // MARK: - CPNowPlayingTemplateObserver

    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        onUpNext?()
    }
}
#endif
