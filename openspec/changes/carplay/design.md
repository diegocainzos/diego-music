## Context

DiegoMusic reproduce audio nativo con una única `AVPlayer` coordinada por `AudioPlayerCoordinator` (un `@MainActor ObservableObject`). El coordinador ya configura `MPRemoteCommandCenter` (play/pause/siguiente/anterior/seek), publica Now Playing en `MPNowPlayingInfoCenter` (título, artista, duración, posición, velocidad y, tras un cambio reciente, carátula vía `MPMediaItemPropertyArtwork`) y activa el modo `playback` de `AVAudioSession` para reproducción en segundo plano. La cola es `PlaybackQueue`, también `@MainActor ObservableObject`.

Hoy no existe ninguna escena ni configurador de CarPlay: la app se controla desde la UI SwiftUI, la pantalla bloqueada y el centro de control. `project.yml` es la fuente de verdad del proyecto Xcode (se regenera con `./scripts/generate-project.sh`); actualmente declara un target `DiegoMusic` para iOS/macOS con `UIBackgroundModes: [audio]` y sin protocolos de accesorios externos.

## Goals / Non-Goals

**Goals:**

- Hacer que DiegoMusic sea usable desde CarPlay: Now Playing, cola, play/pause/siguiente/anterior y navegación básica (browsing).
- Reutilizar `AudioPlayerCoordinator` y `PlaybackQueue` como única fuente de verdad, sin duplicar estado.
- Declarar el protocolo CarPlay (`com.apple.carplay`) en `project.yml` y añadir la escena CarPlay.
- Mantener el `AVPlayer` único y la reproducción en segundo plano, Now Playing y controles remotos existentes.
- Preservar accesibilidad (labels, contraste, áreas táctiles) en la interfaz CarPlay.

**Non-Goals:**

- Rediseñar la reproducción, la cola o el coordinador de audio.
- Añadir LL3 categorías ampliadas (búsqueda/streaming de contenido propio) más allá del flujo base Now Playing + cola + browsing.
- Implementar o verificar el flujo completo de aprovisionamiento CarPlay (exige certificado, entitlements de configuración y revisión de Apple).
- Cambiar `PlayerDock`, `LibraryStore`, `RootView` ni ningún fichero propiedad de otros cambios en curso.

## Decisions

### Scena CarPlay basada en la interfaz `CPTemplateApplicationSceneDelegate`

Se añade un `CarPlaySceneDelegate` que conforma `CPTemplateApplicationSceneDelegate` y un configurador de Now Playing. CarPlay anuncia una escena (`CPNowPlayingTemplate`) que muestra la pista actual, controles play/pause/siguiente/anterior y seek, sincronizada con el `MPNowPlayingInfoCenter`/`MPRemoteCommandCenter` ya configurados por `AudioPlayerCoordinator`. Se añade `CPListTemplate` para la vista de cola (elementos de `PlaybackQueue.items`, con la pista actual marcada y selección que llama a `AudioPlayerCoordinator.select`) y un lijado browsing mínimo (listas a partir de la cola y vínculos a reproducir). La escena consulta `AudioPlayerCoordinator` y `PlaybackQueue` (ya `@MainActor ObservableObject`) en el actor principal.

Alternativa descartada: reimplementar la reproducción en el lado CarPlay. Duplicaría estado y rompería el invariante de un único `AVPlayer`.

### Registro de la escena en `project.yml`

`project.yml` (propiedad exclusiva de este cambio) declara en `info.properties` de `DiegoMusic`:

- `UISupportedExternalAccessoryProtocols: [com.apple.carplay]` (protocolo de externe accessory requerido por CarPlay).
- La escena como `UIApplicationSceneManifest`/escena CarPlay cuando el aruitectura del app lo requiera, o bien vía SwiftUI `CarPlayScene` si se adopta ese estilo. La implementación elegida se fija en las tareas: se prefiere definir un `UIApplicationSceneManifest` en `project.yml` con un `CPTemplateApplicationSceneSessionRoleApplication` apuntando al `CarPlaySceneDelegate`, de modo que no se edite `Info.plist` a mano (se genera desde `project.yml` con XcodeGen).

Regenerar el proyecto con `./scripts/generate-project.sh` (instala XcodeGen si falta). No se edita `DiegoMusic.xcodeproj` manualmente.

### Configurador Now Playing CarPlay

Un pequeño configurador (puede vivir en `CarPlaySceneDelegate` o en un helper `CarPlayNowPlayingConfigurator`) garantiza que el `CPNowPlayingTemplate` refleje el estado del coordinador: subscripción a `@Published` cambios de `playbackState`/`currentTime`/`queue.current` para refrescar `CPNowPlayingTemplate.shared.updateNowPlayingInfo(...)`, y enrutar play/pause/siguiente/anterior hacia `AudioPlayerCoordinator.togglePlayback()/next()/previous()`.

### Honestidad sobre verificación

CarPlay solo puede construirse, ensamblarse y probarse en un dispositivo iOS con Xcode en un Mac (y a menudo en un automóvil o simulador de CarPlay). En el entorno Linux de este cambio solo se escribe código Swift y configuración de proyecto y se valida el cambio OpenSpec. Este riesgo residual se documenta aquí y se deja una tarea de verificación en Mac explícita y no bloqueante para este entorno.

## Risks / Trade-offs

- [CarPlay no verificable en Linux/Mac sin Xcode] → se escribe código + config y se valida con OpenSpec; la verificación de build/ejecución queda como tarea explícita para un Mac. Riesgo residual alto de ajustes de API en el primer build real.
- [Multiplicidad de escenas / AppDelegate inexistente] → se adopta `UIApplicationSceneManifest` declarado desde `project.yml`; si el app no tiene hoy scene manifest, este cambio lo introduce sin tocar el arranque SwiftUI existente más allá de la entrada de escena.
- [Conflicto de `project.yml` con otros cambios] → este cambio es el ÚNICO autorizado a editar `project.yml`, y los otros cambios en curso añaden solo ficheros nuevos (XcodeGen los recoge). El orquestador lo garantiza al delegar.
- [Now Playing CarPlay desincronizado] → el configurador se subcribe a los `@Published` del coordinador y refresca la plantilla en el actor principal.
- [Seam de inyección ajeno] → el punto de inyección de `AudioPlayerCoordinator`/`PlaybackQueue` en la entrada de la escena (`AppEnvironment`/`DiegoMusicApp`) es propiedad del cambio `player-experience`. Este cambio declara esa Dependencia de Merge: la inyección se adjudica y se resuelve al fusionar, sin que `carplay` edite `AppEnvironment`/`DiegoMusicApp`.

## Migration Plan

1. Añadir `UISupportedExternalAccessoryProtocols: [com.apple.carplay]` y el scene manifest en `project.yml`.
2. Crear `DiegoMusic/CarPlay/CarPlaySceneDelegate.swift` (conforma `CPTemplateApplicationSceneDelegate`) y `DiegoMusic/CarPlay/CarPlayNowPlayingConfigurator.swift`.
3. Implementar Now Playing y cola CarPlay reutilizando `AudioPlayerCoordinator` y `PlaybackQueue`. El `CarPlaySceneDelegate` expone un método de inyección (p.ej. `configure(player:queue:)`); la llamada desde la entrada de la escena es una Dependencia de Merge adjudicada con `player-experience` (no se edita `AppEnvironment`/`DiegoMusicApp` aquí).
4. Regenerar el proyecto (`./scripts/generate-project.sh`).
5. Validación OpenSpec estricta en este entorno; build/ejecución CarPlay en Mac (tarea explícita).

Rollback: revertir `project.yml` y borrar los ficheros `DiegoMusic/CarPlay/`; la reproducción queda intacta.

## Open Questions

- Confirmar si el app usa arranque SwiftUI sin `UIApplicationSceneManifest` previo; en tal caso, decidir entre `UIApplicationSceneManifest` (clásico) y `CarPlayScene` SwiftUI en la implementación.
- Verificar en simulador/dispositivo CarPlay cuál es la plantilla de browsing mínima satisfactoria para la cola (decisión de producto que puede iterar tras el primer uso).