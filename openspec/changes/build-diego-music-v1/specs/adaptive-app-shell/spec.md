## ADDED Requirements

### Requirement: Navegación multiplataforma
DiegoMusic SHALL ofrecer Inicio, Búsqueda, Biblioteca, Playlists y Ajustes en iPhone, iPad y macOS mediante navegación adaptada al espacio disponible.

#### Scenario: Presentación amplia
- **WHEN** la aplicación se muestra en iPad o macOS con anchura suficiente
- **THEN** presenta una barra lateral y un detalle usando navegación dividida

#### Scenario: Presentación compacta
- **WHEN** la aplicación se muestra en un iPhone o anchura compacta
- **THEN** presenta navegación compacta sin perder ninguna sección principal

### Requirement: Reproductor persistente
DiegoMusic SHALL mantener un mini reproductor discreto visible mientras exista un elemento actual y SHALL permitir abrir una pantalla ampliada sin perder estado.

#### Scenario: Cambio de presentación
- **WHEN** el usuario abre o cierra el reproductor ampliado
- **THEN** el elemento, estado y posición de reproducción se conservan

### Requirement: Estados comprensibles
Las pantallas de datos SHALL representar explícitamente carga, contenido, vacío y error.

#### Scenario: Error recuperable
- **WHEN** una operación de red falla
- **THEN** la interfaz explica el fallo sin exponer credenciales y ofrece reintento
