## 1. Configuración de proyecto

- [ ] 1.1 Añadir a `project.yml` en `targets.DiegoMusic.info.properties` la clave `UISupportedExternalAccessoryProtocols: [com.apple.carplay]` y un scene manifest para la escena CarPlay (`CPTemplateApplicationSceneSessionRoleApplication` apuntando al `CarPlaySceneDelegate`); sin editar `Info.plist` ni `DiegoMusic.xcodeproj` a mano.
- [ ] 1.2 Regenerar el proyecto con `./scripts/generate-project.sh` y confirmar que el `Info.plist` generado incluye el protocolo y la escena.

## 2. Escena CarPlay

- [ ] 2.1 Crear `DiegoMusic/CarPlay/CarPlaySceneDelegate.swift` conforme a `CPTemplateApplicationSceneDelegate`, que conserve referencias a `AudioPlayerCoordinator` y `PlaybackQueue` (ya `@MainActor ObservableObject`) mediante un método de inyección `configure(player:queue:)`. La llamada de la app es una Dependencia de Merge adjudicada con `player-experience` (este cambio NO edita `AppEnvironment`/`DiegoMusicApp`).
- [ ] 2.2 Configurar `CPNowPlayingTemplate` y refrescarlo con los `@Published` del coordinador (`playbackState`, `currentTime`, `queue.current`) en el actor principal; enrutar play/pause/siguiente/anterior a `togglePlayback()/next()/previous()`.

## 3. Cola y browsing

- [ ] 3.1 Crear `DiegoMusic/CarPlay/CarPlayNowPlayingConfigurator.swift` (o equivalente) que sincronice estado entre coordinador/cola y las plantillas CarPlay.
- [ ] 3.2 Añadir `CPListTemplate` con la cola (`PlaybackQueue.items`), marcando la pista actual y enrutando la selección a `AudioPlayerCoordinator.select`; aportar browsing mínimo (lista de la cola y vínculo a reproducir).

## 4. Validación

- [ ] 4.1 Validar el cambio OpenSpec estricto en este entorno: `openspec validate carplay --type change --strict`.
- [ ] 4.2 Documentar como tarea NO bloqueante en este entorno la verificación de build/ejecución de CarPlay en un Mac con Xcode (y simulador/dispositivo CarPlay), incluyendo aprovisionamiento y entitlements/escena.
