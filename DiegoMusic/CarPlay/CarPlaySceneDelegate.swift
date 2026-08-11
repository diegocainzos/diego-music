#if os(iOS)
import CarPlay
import UIKit

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
            CPNowPlayingTemplate.shared.remove(configurator)
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

        // 1. Pestaña Favoritos (Lista vertical simple)
        let favoritesTemplate = buildFavoritesTemplate()

        // 2. Pestaña Recientes (Lista vertical simple)
        let recentsTemplate = buildRecentsTemplate()

        // 3. Pestaña Ahora Suena (Plantilla nativa de reproductor)
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isUpNextButtonEnabled = true
        nowPlaying.upNextTitle = "Cola"
        if #available(iOS 14.0, *) {
            nowPlaying.tabTitle = "Ahora suena"
            nowPlaying.tabImage = UIImage(systemName: "play.circle.fill")
        }

        let configurator = CarPlayNowPlayingConfigurator(player: player, queue: queue)
        configurator.onUpNext = { [weak self] in
            guard let self, let interfaceController = self.interfaceController else { return }
            self.presentQueue(on: interfaceController)
        }
        CPNowPlayingTemplate.shared.add(configurator)
        self.configurator = configurator

        // Construir la barra de pestañas principal
        let tabBar = CPTabBarTemplate(templates: [favoritesTemplate, recentsTemplate, nowPlaying])
        interfaceController.setRootTemplate(tabBar, animated: false)
    }

    /// Construye la plantilla de lista vertical para Favoritos.
    private func buildFavoritesTemplate() -> CPListTemplate {
        let favorites = AppEnvironment.shared?.library.favorites ?? []
        let items: [CPListItem] = favorites.map { track in
            let listItem = CPListItem(
                text: track.title,
                detailText: track.channelTitle,
                image: nil,
                showsDisclosureIndicator: false
            )
            listItem.handler = { _, completion in
                AppEnvironment.shared?.play(track.mediaItem)
                completion()
            }
            return listItem
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Favoritos", sections: [section])
        if #available(iOS 14.0, *) {
            template.tabTitle = "Favoritos"
            template.tabImage = UIImage(systemName: "heart.fill")
        }
        return template
    }

    /// Construye la plantilla de lista vertical para Recientes.
    private func buildRecentsTemplate() -> CPListTemplate {
        let history = AppEnvironment.shared?.library.history ?? []
        let items: [CPListItem] = history.map { track in
            let listItem = CPListItem(
                text: track.title,
                detailText: track.channelTitle,
                image: nil,
                showsDisclosureIndicator: false
            )
            listItem.handler = { _, completion in
                AppEnvironment.shared?.play(track.mediaItem)
                completion()
            }
            return listItem
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "Recientes", sections: [section])
        if #available(iOS 14.0, *) {
            template.tabTitle = "Recientes"
            template.tabImage = UIImage(systemName: "clock.fill")
        }
        return template
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
