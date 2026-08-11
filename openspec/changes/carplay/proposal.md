## Why

DiegoMusic es un reproductor privado iOS/iPadOS 17+ que hoy se controla solo desde la propia app, la pantalla bloqueada y el centro de control. Un usuario de streaming espera poder seguir escuchando y administrando la reproducción desde el coche. Sin compatibilidad con CarPlay, la app queda corta frente a la experiencia que ya ofrecen sus competidores y no aprovecha que `AudioPlayerCoordinator` ya expone un único `AVPlayer` con controles remotos y Now Playing.

## What Changes

- Añadir compatibilidad con CarPlay: una escena CarPlay que ofrece Now Playing, vista de cola, play/pause/siguiente/anterior y navegación básica (browsing), todo orquestado por el `AudioPlayerCoordinator` existente como fuente única de verdad.
- Editar `project.yml` para declarar el protocolo externo soportado (`UISupportedExternalAccessoryProtocols` = `com.apple.carplay`) y cualquier ajuste de escena/info necesario. Este cambio es el ÚNICO autorizado a modificar `project.yml`.
- Añadir ficheros nuevos bajo `DiegoMusic/CarPlay/` (escena CarPlay y configurador de Now Playing). XcodeGen los incorpora automáticamente al regenerar; no se edita `DiegoMusic.xcodeproj` a mano.
- Reutilizar tal cual `AudioPlayerCoordinator`, `PlaybackQueue` y `MPRemoteCommandCenter`; CarPlay no duplica estado de reproducción.

## Capabilities

### New Capabilities

- `carplay`: compatibilidad de DiegoMusic con CarPlay — escena CarPlay con Now Playing, cola y controles de reproducción alimentados por el coordinador de audio existente.

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ no existe aún). Este cambio es ADDED y convive con los deltas en curso (`native-audio-playback`, `minimal-apple-music-aesthetic`); no los modifica. El único fichero de proyecto tocado es project.yml, propiedad de este cambio. -->

## Impact

- Cliente: `project.yml` (configuración Info.plist + posibles ajustes de escena) y nuevos ficheros bajo `DiegoMusic/CarPlay/`.
- Comportamiento: DiegoMusic se vuelve usable desde CarPlay con controles y cola, sin cambios en la lógica de reproducción.
- Sin cambios en ResolutionService, API/URLs de YouTube, persistencia ni en la semántica de cola/`AVPlayer`.
- Sin cambios en `PlayerDock`, `PlaybackQueue`, `AudioPlayerCoordinator`, `LibraryStore` ni `RootView` (propiedad de otros cambios); este cambio solo los REUTILIZA como lectura.
- La accesibilidad existente (labels, reduce motion, contraste) se conserva.