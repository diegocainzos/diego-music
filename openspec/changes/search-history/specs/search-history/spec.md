## ADDED Requirements

### Requirement: Historial reciente de búsquedas
DiegoMusic SHALL persistir localmente las consultas de búsqueda recientes del usuario y mostrarlas al enfocar el campo de búsqueda o cuando no hay ninguna consulta activa, con las más recientes primero y sin duplicados.

#### Scenario: Sin consulta activa
- **WHEN** el usuario abre la búsqueda o enfoca el campo sin escribir nada
- **THEN** se muestran las últimas consultas recientes guardadas, ordenadas de más reciente a más antigua

#### Scenario: Búsqueda exitosa
- **WHEN** el usuario completa una búsqueda con éxito y la consulta no está vacía
- **THEN** la consulta se guarda al frente del historial, deduplicándose si ya existía

#### Scenario: Consulta seleccionada desde el historial
- **WHEN** el usuario elige una consulta reciente
- **THEN** el campo se rellena con esa consulta y se ejecuta la búsqueda

### Requirement: Selector de ámbito de búsqueda
DiegoMusic SHALL ofrecer un selector de ámbito (Todo / Canciones / Álbumes / Artistas / Letras) que filtre el mismo conjunto de resultados devueltos por YouTube en el cliente, sin lanzar peticiones adicionales.

#### Scenario: Filtrar por tipo
- **WHEN** el usuario selecciona Canciones, Álbumes o Artistas
- **THEN** los resultados se filtran por el tipo correspondiente de `MediaItem` (`video`, `playlist`/`video`, `channel`) conservando el resto de la interacción

#### Scenario: Filtro «Letras» honesto
- **WHEN** el usuario selecciona Letras
- **THEN** el filtro reduce visualmente los resultados por coincidencia de título/canal como heurística best-effort, sin prometer búsqueda semántica de texto de letras (DiegoMusic no dispone de índice de letras)

#### Scenario: Cambio de ámbito sin nueva petición
- **WHEN** el usuario cambia el ámbito sobre unos resultados ya cargados
- **THEN** no se lanza una nueva petición de red y solo se actualiza la presentación filtrada

#### Scenario: Filtrado vacío
- **WHEN** el ámbito activo deja sin coincidencias los resultados
- **THEN** se muestra un estado vacío propio del ámbito, distinto de «sin resultados en YouTube»

### Requirement: Búsqueda con debounce y cancelación
DiegoMusic SHALL ejecutar la búsqueda con un pequeño debounce al cambiar la consulta y cancelar la tarea anterior, reutilizando los estados de presentación existentes y manteniendo mensajes de error sanitizados.

#### Scenario: Escritura continuada
- **WHEN** el usuario escribe varias consultas seguidas
- **THEN** solo se lanza la búsqueda tras el periodo de debounce y se cancela cualquier petición anterior, evitando resultados obsoletos

#### Scenario: Error de red
- **WHEN** la búsqueda falla
- **THEN** se muestra un mensaje sanitizado basado en `LocalizedError` sin excepciones crudas de red/HTTP

### Requirement: Accesibilidad del historial y del selector
El historial reciente y el selector de ámbito SHALL proporcionar etiquetas accesibles y reducir animación cuando el sistema lo solicite.

#### Scenario: Control solo con icono o segmento rotulado
- **WHEN** el usuario interactúa con el selector de ámbito o una entrada del historial
- **THEN** cada control proporciona una etiqueta accesible que explica su acción y el estado seleccionado

#### Scenario: Reducir movimiento activo
- **WHEN** `accessibilityReduceMotion` está activado
- **THEN** las transiciones del selector y del historial se simplifican o se muestran sin animación
