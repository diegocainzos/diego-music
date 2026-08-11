## ADDED Requirements

### Requirement: Biblioteca local explorable
DiegoMusic SHALL exponer la colección local del usuario a través de vistas agrupadas Canciones, Álbumes, Artistas y Listas, derivadas únicamente de los registros locales (favoritos e historial en Core Data), sin llamadas nuevas a YouTube.

#### Scenario: Abrir la Biblioteca
- **WHEN** el usuario entra en Biblioteca
- **THEN** ve una navegación con Canciones, Álbumes, Artistas y Listas agrupadas a partir de los favoritos e historial locales

#### Scenario: Álbumes y artistas local
- **WHEN** el usuario abre Álbumes o Artistas
- **THEN** los grupos se calculan en memoria desde los registros locales sin consultar la red

### Requirement: Guardar / quitar canciones en la biblioteca
DiegoMusic SHALL permitir guardar y quitar canciones de la biblioteca reutilizando los favoritos existentes, expuestos de forma coherente en las nuevas vistas.

#### Scenario: Corazón en la biblioteca
- **WHEN** el usuario activa o desactiva el corazón en una canción de la biblioteca
- **THEN** la canción se guarda o se quita de la colección local y la interfaz refleja el estado al instante

### Requirement: Búsqueda dentro de la biblioteca
DiegoMusic SHALL permitir buscar dentro de la colección local por título de canción, artista y álbum, filtrando en cliente las colecciones derivadas de forma instantánea.

#### Scenario: Consulta local
- **WHEN** el usuario escribe una consulta en la búsqueda de la biblioteca
- **THEN** las vistas Canciones/Álbumes/Artistas/Listas se filtran por título, artista o álbum local sin consumir cuota de YouTube

#### Scenario: Sin resultados
- **WHEN** la consulta local no coincide con ningún elemento
- **THEN** se muestra un estado vacío claro que invita a cambiar la consulta

### Requirement: Gestión completa de playlists
DiegoMusic SHALL permitir crear, renombrar, borrar y reordenar listas de reproducción locales, incluyendo el renombrado que hoy no existe.

#### Scenario: Renombrar una playlist
- **WHEN** el usuario renombra una playlist local
- **THEN** el nuevo nombre se persiste en Core Data y se refleja en la interfaz

#### Scenario: Reordenar y borrar
- **WHEN** el usuario reordena elementos o borra una lista
- **THEN** los cambios se mantienen localmente y las posiciones se normalizan

### Requirement: Corazón "Me gusta" y recomendaciones locales
DiegoMusic SHALL ofrecer un listado automático "Me gusta" derivado de los favoritos y una heurística local de recomendaciones basada en esos favoritos, sin depender de la red.

#### Scenario: Listado Me gusta
- **WHEN** el usuario consulta su listado "Me gusta"
- **THEN** se muestran las canciones marcadas con corazón, derivadas de los favoritos locales

#### Scenario: Recomendaciones heurísticas
- **WHEN** la biblioteca sugiere recomendaciones
- **THEN** estas se calculan localmente (mismos artistas favoritos / historia común priorizada por frecuencia) sin llamadas de red

### Requirement: Cableado sin romper la reproducción
DiegoMusic SHALL integrar las nuevas vistas de biblioteca en `RootView` sin modificar `PlayerDock` ni `AudioPlayerCoordinator`.

#### Scenario: Navegación nueva preserva player
- **WHEN** el usuario navega por las nuevas vistas de biblioteca
- **THEN** el `PlayerDock` y la reproducción en curso siguen intactos y operativos en la parte inferior

### Requirement: Accesibilidad preservada
Las nuevas vistas SHALL conservar la accesibilidad del sistema vigente: etiquetas accesibles, foco de teclado, contraste legible, áreas táctiles ≥ 44pt y `accessibilityReduceMotion`.

#### Scenario: Controles y foco
- **WHEN** la biblioteca se muestra con la nueva estructura
- **THEN** los controles mantienen etiquetas accesibles, foco de teclado y áreas táctiles adecuadas; con `accessibilityReduceMotion` activo, las transiciones se simplifican
