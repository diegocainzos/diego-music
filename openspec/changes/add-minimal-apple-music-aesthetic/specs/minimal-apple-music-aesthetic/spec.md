## ADDED Requirements

### Requirement: Identidad visual mínima tipo Apple Music
DiegoMusic SHALL sustituir la identidad Bauhaus Hi‑Fi por un sistema de diseño mínimo con superficies claras, tipografía de sistema, esquinas redondeadas, sombras suaves o ausentes y un único acento cromático (el rojo actual de DiegoMusic), aplicado de forma coherente en todas las pantallas.

#### Scenario: Pantalla principal
- **WHEN** se muestra Inicio
- **THEN** la interfaz usa superficies claras y tipografía de sistema sin trazos de tinta ni sombras de offset duras, y ningún elemento conserva la retícula Bauhaus ni los acentos amarillo/azul

#### Scenario: Acción de botón
- **WHEN** el usuario pulsa un botón de control
- **THEN** el botón conserva un área táctil adecuada y su acento rojo, sin los bordes duros de 2px del sistema anterior

### Requirement: Reproductor rediseñado con carátula protagonista
El reproductor musical (estados compacto y ampliado) SHALL centrar la carátula de la pista, ofrecer un fondo ambiental derivado de la carátula y mantener la semántica de cola, progreso y controles sin cambios.

#### Scenario: Presentación compacta
- **WHEN** una pista está activa y el dock permanece contraído
- **THEN** la carátula redondeada, título y canal se muestran con la nueva estética y los controles play/pause, anterior y siguiente siguen disponibles

#### Scenario: Presentación ampliada
- **WHEN** el usuario amplía el dock
- **THEN** la carátula domina la presentación, el fondo ambiental se deriva de la carátula y el progreso y editor de cola conservan su comportamiento

#### Scenario: Reducir movimiento activo
- **WHEN** `accessibilityReduceMotion` está activado
- **THEN** las transiciones y el fondo ambiental se simplifican o se muestran sin animación

### Requirement: Carátula en pantalla bloqueada y centro de control
DiegoMusic SHALL publicar la carátula de la pista activa mediante `MPMediaItemPropertyArtwork` en `MPNowPlayingInfoCenter`, de modo que la pantalla bloqueada y el centro de control muestren la portada real junto a los metadatos existentes.

#### Scenario: Pista con carátula disponible
- **WHEN** una pista con `thumbnailURL` empieza a reproducirse
- **THEN** la pantalla bloqueada recibe los metadatos de texto y la carátula de la pista

#### Scenario: Carátula aún no cargada
- **WHEN** la carátula tarda en descargarse
- **THEN** los metadatos de texto se publican inmediatamente y la carátula se añade cuando esté lista, sin bloquear la reproducción ni el hilo principal

### Requirement: Caché compartida de carátulas
DiegoMusic SHALL disponer de una caché pequeña en memoria de carátulas, compartida entre la interfaz del reproductor y la publicación de Now Playing, con tamaño limitado y comportamiento de reemplazo LRU.

#### Scenario: Misma carátula en reproductor y lockscreen
- **WHEN** una pista muestra carátula en el dock y en la pantalla bloqueada
- **THEN** ambos consumidores reutilizan la misma imagen cacheada sin descargas duplicadas

#### Scenario: Caché llena o fallo de red
- **WHEN** la caché alcanza su límite o la descarga falla
- **THEN** las entradas antiguas se expulsan y cada consumidor conserva su placeholder actual

### Requirement: Accesibilidad preservada
El rediseño SHALL conservar los requisitos de accesibilidad del sistema anterior: etiquetas accesibles en controles, contraste suficiente, foco de teclado y reducción de animación cuando el sistema lo solicite.

#### Scenario: Control solo con icono
- **WHEN** un botón muestra únicamente un símbolo
- **THEN** proporciona una etiqueta accesible que explica su acción

#### Scenario: Contraste y foco
- **WHEN** la interfaz se muestra con la nueva paleta
- **THEN** el texto mantiene contraste legible y los controles conservan foco e indicaciones de estado accesibles