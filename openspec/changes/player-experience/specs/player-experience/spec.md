## ADDED Requirements

### Requirement: Modos shuffle y repeat
DiegoMusic SHALL ofrecer modos de reproducción conmutable desde el reproductor: shuffle (activado/desactivado) y repeat con estados `off`, `all` y `one`, respetando la pista activa y la semántica de la cola sin duplicar pistas.

#### Scenario: Repeat one
- **WHEN** la pista activa termina con repeat en `one`
- **THEN** se vuelve a cargar y reproducir la misma pista, en lugar de avanzar

#### Scenario: Repeat all
- **WHEN** la cola llega a su última pista con repeat en `all`
- **THEN** la cola reinicia su orden y continúa desde la primera pista

#### Scenario: Shuffle activado
- **WHEN** el usuario activa shuffle
- **THEN** la cola se reproduce en un orden aleatorio sin pistas duplicadas y la pista activa se conserva

#### Scenario: Shuffle desactivado
- **WHEN** el usuario desactiva shuffle
- **THEN** se restaura el orden original de la cola y la pista activa se mantiene

### Requirement: Cola reordenable por arrastre
El editor de cola del reproductor ampliado SHALL permitir reordenar las pistas por arrastre ("toca para poner después"), además de las flechas de subir/bajar existentes, conservando la accesibilidad de la reordenación.

#### Scenario: Reordenar por arrastre
- **WHEN** el usuario arrastra un elemento de la cola a otra posición
- **THEN** la cola se reordena llamando a `queue.move(from:to:)` y la pista activa se conserva

#### Scenario: Reordenar sin arrastre
- **WHEN** el usuario usa las flechas de subir/bajar
- **THEN** la reordenación sigue disponible y accesible sin necesitar gesto de arrastre

### Requirement: Continuar donde lo dejaste
DiegoMusic SHALL persistir la pista activa y su posición, y restaurarlas al reabrir la app, de forma opcional y respetada por ajustes, quedando en pausa sin auto-reproducción no deseada.

#### Scenario: Restaurar reproducción al reabrir
- **WHEN** la app se abre de nuevo con una pista guardada y el ajuste activo
- **THEN** la pista se restaura en la cola y se posiciona en el punto anterior, en pausa

#### Scenario: Ajuste desactivado
- **WHEN** el usuario desactiva "continuar donde lo dejaste"
- **THEN** no se persiste ni se restaura la reproducción al reabrir

### Requirement: Gestos del reproductor ampliado
El reproductor ampliado SHALL ofrecer gestos: deslizar horizontalmente para pasar a siguiente/anterior y arrastrar hacia abajo para cerrarlo, manteniendo botones de control grandes (≥ 44pt) y etiquetas accesibles, y respetando `accessibilityReduceMotion` en las animaciones.

#### Scenario: Deslizar para siguiente
- **WHEN** el usuario desliza horizontalmente sobre la carátula en el ampliado
- **THEN** se reproduce la siguiente pista al superar el umbral

#### Scenario: Arrastrar hacia abajo para cerrar
- **WHEN** el usuario arrastra el ampliado hacia abajo superando el umbral
- **THEN** el reproductor ampliado se contrae, con animación suprimida si `accessibilityReduceMotion` está activo

### Requirement: Autoplay/radio best-effort con proveedor inyectado
DiegoMusic SHALL poder encadenar música relacionada al terminar la cola mediante un proveedor inyectado (`RelatedTrackProviding`), de forma best-effort: ante error o ausencia de resultado se mantiene el comportamiento de detención actual sin interrumpir la pista en curso.

#### Scenario: Fin de cola con proveedor disponible
- **WHEN** la cola termina con repeat `off` y hay un proveedor relacionado
- **THEN** se solicita una pista relacionada y, si se obtiene, se encola y reproduce

#### Scenario: Proveedor ausente o error
- **WHEN** no hay proveedor relacionado o este falla
- **THEN** la reproducción se detiene como hasta ahora, sin error visible y sin encolar pistas no deseadas

### Requirement: Reproducción nativa y accesibilidad preservadas
Los cambios SHALL conservar un único `AVPlayer` coordinado por `AudioPlayerCoordinator`, audio en segundo plano, Now Playing/carátula y la accesibilidad existente (etiquetas, `accessibilityReduceMotion`, contraste, foco, áreas táctiles ≥ 44pt).

#### Scenario: Un solo motor de audio
- **WHEN** los modos y gestos están activos
- **THEN** sigue existiendo un único `AVPlayer` gestionado por `AudioPlayerCoordinator`, sin motores adicionales

#### Scenario: Control solo con icono
- **WHEN** un control nuevo (shuffle, repeat, gestos) muestra solo un símbolo
- **THEN** proporciona una etiqueta accesible y área táctil adecuada que explica su acción y estado
