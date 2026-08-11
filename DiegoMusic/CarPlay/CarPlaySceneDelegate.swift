import CarPlay
import UIKit

#if os(iOS)
/// Escena CarPlay de DiegoMusic.
///
/// Conforma `CPTemplateApplicationSceneDelegate` y usa el `AudioPlayerCoordinator`
/// y `PlaybackQueue` existentes como única fuente de verdad: no se duplica estado,
/// ni controles ni motor de reproducción. La inyección de `player`/`queue` es una
/// Dependencia de Merge adjudicada con el cambio `player-experience`; este fichero
/// NO toca `AppEnvironment`/`DiegoMusicApp`.
@MainActor
final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {

    /// Punto de entrada para la inyección desde la app (se llama tras el merge).
    /// Queda accesible vía `CarPlaySceneDelegate.shared` cuando la escena está viva.
    static weak var shared: CarPlaySceneDelegate?

    private var player: AudioPlayerCoordinator?
    private var queue: PlaybackQueue?
    private var interfaceController: CPInterfaceController?
    private var configurator: CarPlayNowPlayingConfigurator?

    /// Inyección de dependencias (Dependencia de Merge con `player-experience`).
    func configure(player: AudioPlayerCoordinator, queue: PlaybackQueue) {
        self.player = player
        self.queue = queue
        rebuildInterfaceIfReady()
    }

    // MARK: - CPTemplateApplicationSceneDelegate

    func scene(
        _ scene: CPTemplateApplicationScene,
        willConnectTo interfaceController: CPInterfaceController,
        window: CPWindow
    ) {
        CarPlaySceneDelegate.shared = self
        self.interfaceController = interfaceController
        // Inyección del seam de merge: obtiene player/queue de la app y conecta
        // el coordinador existente como única fuente de verdad.
        if let environment = AppEnvironment.shared {
            configure(player: environment.player, queue: environment.queue)
        }
        rebuildInterfaceIfReady()
    }

    func sceneDidDisconnect(
        _ scene: CPTemplateApplicationScene,
        from interfaceController: CPInterfaceController
    ) {
        if let configurator {
            CPNowPlayingTemplate.shared.removeObserver(configurator)
        }
        configurator = nil
        self.interfaceController = nil
        if CarPlaySceneDelegate.shared === self {
            CarPlaySceneDelegate.shared = nil
        }
    }

    // MARK: - Composición

    private func rebuildInterfaceIfReady() {
        guard let player, let queue, let interfaceController else { return }

        // Ahora suena: CarPlay es una plantilla del sistema que refleja
        // MPNowPlayingInfoCenter/MPRemoteCommandCenter ya configurados por el
        // coordinador; aquí solo se activa el botón "Cola" y se sincroniza.
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isUpNextButtonEnabled = true
        nowPlaying.upNextTitle = "Cola"

        let configurator = CarPlayNowPlayingConfigurator(player: player, queue: queue)
        configurator.onUpNext = { [weak self] in
            guard let self, let interfaceController = self.interfaceController else { return }
            self.presentQueue(on: interfaceController)
        }
        CPNowPlayingTemplate.shared.addObserver(configurator)
        self.configurator = configurator
        configurator.refresh()

        interfaceController.setRootTemplate(nowPlaying, animated: false)
    }

    /// Vista de cola (browsing mínimo): elementos de la cola con la pista actual
    /// marcada; la selección enruta a `AudioPlayerCoordinator.select`.
    private func presentQueue(on interfaceController: CPInterfaceController) {
        guard let player, let queue else { return }

        let items = queue.items.map { item in
            let isCurrent = item.id == queue.current?.id
            let listItem = CPListItem(
                text: item.title,
                detailText: item.channelTitle,
                image: nil,
                showsDisclosureIndicator: false
            )
            if #available(iOS 15.0, *) {
                listItem.isPlaying = isCurrent
            }
            listItem.handler = { [weak self] _, completion in
                self?.player?.select(item)
                completion()
            }
            return listItem
        }

        let section = CPListSection(items: items)
        let list = CPListTemplate(title: "Cola", sections: [section])
        interfaceController.pushTemplate(list, animated: true)
    }
}
#endif
