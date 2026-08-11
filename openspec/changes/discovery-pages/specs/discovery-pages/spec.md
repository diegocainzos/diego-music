## ADDED Requirements

### Requirement: Descubrimiento en Inicio
DiegoMusic SHALL mostrar en Inicio una sección de descubrimiento ("Descubrir / Novedades") poblada por resultados públicos de YouTube, presentada como contenido público y no personalizado, con estados de carga, vacío y error sanitizado y una acción de reintento.

#### Scenario: Inicio con contenido disponible
- **WHEN** se abre Inicio y la red/cuota lo permiten
- **THEN** se muestra una sección de novedades con resultados públicos de YouTube, claramente etiquetada como contenido público no personalizado

#### Scenario: Inicio sin contenido o con error
- **WHEN** el feed falla o devuelve vacío
- **THEN** Inicio muestra un estado vacío o un error sanitizado con opción de reintentar, sin interrumpir el resto de la app

### Requirement: Página de artista
DiegoMusic SHALL ofrecer una página de artista que muestre su perfil, top tracks, discografía (compatible con canales que agrupan por `channelId`) y relacionados, alimentada por los endpoints de canales y vídeos de YouTube.

#### Scenario: Abrir artista desde un resultado
- **WHEN** el usuario pulsa un resultado que pertenece a un canal/artista
- **THEN** se navega por push a una página de artista con su perfil, top tracks, discografía y relacionados

#### Scenario: Artista sin canales distinguibles
- **WHEN** el canal no permite diferenciar artistas
- **THEN** la página agrupa por `channelId` y documenta la limitación sin romper la presentación

### Requirement: Página de álbum
DiegoMusic SHALL ofrecer una página de álbum que muestre la lista de pistas correspondiente, alimentada por el endpoint `playlistItems` de YouTube.

#### Scenario: Abrir álbum desde un resultado
- **WHEN** el usuario pulsa una playlist/álbum
- **THEN** se navega por push a una página de álbum con su lista de pistas

#### Scenario: Error al cargar el álbum
- **WHEN** la carga de pistas falla o devuelve vacío
- **THEN** se muestra un error sanitizado o estado vacío con opción de reintento

### Requirement: Extensión sin romper la capa existente
La capa de YouTube SHALL ampliarse con métodos async nuevos (artista/álbum) sin cambiar la firma existente `search(query:pageToken:)`, con implementación por defecto en el protocolo para no obligar a los conformantes actuales a cambiar.

#### Scenario: Métodos nuevos disponibles
- **WHEN** se compila la app
- **THEN** `YouTubeDataServicing` expone los métodos nuevos y el método `search(query:pageToken:)` conserva su firma y comportamiento actuales

#### Scenario: Manejo de credenciales
- **WHEN** la capa de YouTube construye peticiones
- **THEN** la `apiKey` se maneja exactamente como hoy (en `YouTubeEndpoint`, nunca logueada) y los errores devueltos al cliente están sanitizados

### Requirement: Navegación por push desde Inicio
Las páginas de artista y álbum SHALL ser alcanzables por navegación push (`NavigationStack` + `navigationDestination`) desde Inicio, sin modificar `RootView`. Este cambio NO edita `SearchView` (propiedad de `search-history`); la entrada opcional desde Búsqueda es una dependencia de merge coordinada con ese cambio.

#### Scenario: Navegar a contexto
- **WHEN** el usuario pulsa una celda de artista o álbum en Inicio o en los resultados de búsqueda
- **THEN** se empuja la página correspondiente manteniendo el gesto de volver atrás

#### Scenario: Accesibilidad
- **WHEN** se muestran las nuevas páginas
- **THEN** se conservan etiquetas accesibles, contraste y `accessibilityReduceMotion` en las transiciones
