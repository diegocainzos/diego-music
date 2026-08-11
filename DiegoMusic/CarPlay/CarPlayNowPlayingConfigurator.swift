#if os(iOS)
import CarPlay
import Foundation

/// Habilita el botón "Cola" en el Now Playing de CarPlay. Los metadatos de Now
/// Playing ya se publican en `MPNowPlayingInfoCenter` por el coordinador, y la
/// plantilla del sistema los refleja automáticamente; aquí solo se enruta la
/// pulsación del botón de cola al actor principal.
@MainActor
final class CarPlayNowPlayingConfigurator: NSObject, CPNowPlayingTemplateObserver {

    private let player: AudioPlayerCoordinator
    private let queue: PlaybackQueue

    /// Invocado al pulsar "Cola" en el Now Playing de CarPlay.
    var onUpNext: (() -> Void)?

    init(player: AudioPlayerCoordinator, queue: PlaybackQueue) {
        self.player = player
        self.queue = queue
        super.init()
    }

    // MARK: - CPNowPlayingTemplateObserver

    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        onUpNext?()
    }
}
#endif
