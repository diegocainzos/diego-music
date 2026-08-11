## ADDED Requirements

### Requirement: Compatibilidad con CarPlay
DiegoMusic SHALL ser compatible con CarPlay, ofreciendo una escena CarPlay con Now Playing, vista de cola, controles de reproducción (play/pause/siguiente/anterior) y navegación básica, alimentada por el `AudioPlayerCoordinator` y `PlaybackQueue` existentes como única fuente de verdad.

#### Scenario: Conexión a CarPlay
- **WHEN** el dispositivo compatible se conecta a un automóvil compatible con CarPlay
- **THEN** DiegoMusic aparece como app de audio con CarPlay y muestra la interfaz Now Playing con la pista actual

#### Scenario: Control desde CarPlay
- **WHEN** el usuario pulsa play/pause, siguiente o anterior en CarPlay
- **THEN** la acción enruta a `AudioPlayerCoordinator` y el único `AVPlayer` cambia de estado sin duplicar estado de reproducción

### Requirement: Now Playing y cola en CarPlay
La escena CarPlay SHALL mostrar la pista actual (Now Playing) y una vista de la cola de reproducción, sincronizadas con el estado observable del coordinador y la cola.

#### Scenario: Pista activa
- **WHEN** hay una pista actual en la cola
- **THEN** CarPlay muestra sus metadatos y su carátula y permite reproducir/pausar y saltar de pista

#### Scenario: Vista de cola
- **WHEN** el usuario navega a la cola en CarPlay
- **THEN** se listan los elementos de la cola con la pista actual marcada y la selección de un elemento llama a `PlaybackQueue`/`AudioPlayerCoordinator`

### Requirement: Configuración del protocolo CarPlay en el proyecto
El proyecto SHALL declarar en `project.yml` (fuente de verdad) el protocolo de accesorio externo `com.apple.carplay` y la escena CarPlay, regenerando el proyecto con `./scripts/generate-project.sh` en lugar de editar `DiegoMusic.xcodeproj` a mano.

#### Scenario: Regeneración del proyecto
- **WHEN** se regenera el proyecto tras este cambio
- **THEN** `Config/Info.plist` generado contiene `UISupportedExternalAccessoryProtocols` con `com.apple.carplay` y la escena CarPlay queda declarada para el target iOS

#### Scenario: Propiedad exclusiva de project.yml
- **WHEN** otro cambio en curso añade ficheros nuevos
- **THEN** esos cambios no editan `project.yml`; este cambio es el único responsable de los cambios de proyecto

### Requirement: Un único AVPlayer como fuente de verdad
La integración CarPlay SHALL reutilizar el `AudioPlayerCoordinator` y la sesión de audio existentes, sin crear un segundo motor de reproducción ni duplicar el estado Now Playing/cola.

#### Scenario: Estado compartido
- **WHEN** la reproducción cambia desde la app o desde CarPlay
- **THEN** ambos reflejan el mismo estado porque comparten el coordinador y la cola, manteniendo la reproducción en segundo plano y los controles remotos existentes

### Requirement: Verificación en entorno con Xcode
El cambio SHALL documentar explícitamente que la compilación y ejecución de CarPlay requieren un Mac con Xcode y, idealmente, un dispositivo/simulador CarPlay, y SHALL dejar una tarea de verificación en ese entorno.

#### Scenario: Entorno sin Xcode
- **WHEN** el cambio se valida en un host sin Xcode (p. ej. Linux)
- **THEN** la validación OpenSpec pasa y el build/ejecución de CarPlay queda como riesgo residual documentado y tarea explícita no bloqueante en Mac
