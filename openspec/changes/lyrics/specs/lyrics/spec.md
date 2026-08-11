## ADDED Requirements

### Requirement: Vista de letras sincronizadas con auto‑scroll
DiegoMusic SHALL ofrecer una vista de letras sincronizadas (`LyricsView`) que muestre la letra de la pista activa y desplace automáticamente a la línea correspondiente según el tiempo de reproducción.

#### Scenario: Pista con letra disponible
- **WHEN** hay una letra sincronizada disponible y avanza el tiempo de reproducción
- **THEN** la vista resalta la línea activa y se desplaza automáticamente a ella

#### Scenario: Reducir movimiento activo
- **WHEN** `accessibilityReduceMotion` está activado
- **THEN** el desplazamiento automático salta a la línea activa sin animación continua

#### Scenario: Sin matriz de tiempo
- **WHEN** la letra no tiene marcas temporales
- **THEN** la vista muestra la letra sin auto‑scroll y degrada con elegancia

### Requirement: Contrato público de proveedor de letras
DiegoMusic SHALL exponer un contrato público `LyricsProviding` que, dado el `MediaItem` activo y el tiempo actual, devuelva la letra sincronizada, de modo que la integración en el reproductor ampliado pueda inyectarse sin acoplar esta capability a la cola o al coordinador de audio.

#### Scenario: Proveedor devuelve letra
- **WHEN** el proveedor devuelve líneas con marcas temporales válidas
- **THEN** `LyricsView` las presenta y sincroniza con el tiempo de reproducción

#### Scenario: Sin proveedor o sin letra
- **WHEN** no hay proveedor configurado o devuelve `nil`/vacío
- **THEN** la vista muestra un estado vacío claro y no interrumpe la reproducción

### Requirement: Letras sin scraping con copyright
DiegoMusic SHALL NO scrapear letras con derechos de autor y SHALL tratar la obtención de letras como best‑effort y opcional, con un proveedor local/experimental por defecto.

#### Scenario: Default experimental
- **WHEN** no hay proveedor de red configurado
- **THEN** solo se usa el proveedor local/experimental, que puede devolver ejemplos embebidos etiquetados o `nil`, y nunca fabrica resultados sobre letras reales con copyright

### Requirement: Autocontenida bajo DiegoMusic/Lyrics
La capability `lyrics` SHALL residir en ficheros nuevos bajo `DiegoMusic/Lyrics/` y SHALL NO modificar `PlaybackQueue`, `AudioPlayerCoordinator`, `PlayerDock`, `LibraryStore`, `RootView`, `YouTubeDataService` ni `project.yml`.

#### Scenario: Aislamiento de ficheros
- **WHEN** se implementa la capability
- **THEN** solo se añaden o modifican ficheros bajo `DiegoMusic/Lyrics/` y ningún fichero de otro cambio se ve alterado

### Requirement: Accesibilidad de la letra
La vista de letras SHALL ser accesible: VoiceOver anuncia la línea actual y se respeta `accessibilityReduceMotion`, manteniendo contraste legible del texto sobre su fondo.

#### Scenario: VoiceOver
- **WHEN** VoiceOver está activo y cambia la línea activa
- **THEN** la línea actual se anuncia accesiblemente

#### Scenario: Contraste y movimiento
- **WHEN** la letra se muestra con el modo experimental
- **THEN** el texto mantiene contraste legible y las animaciones de scroll se reducen si `accessibilityReduceMotion` está activo
