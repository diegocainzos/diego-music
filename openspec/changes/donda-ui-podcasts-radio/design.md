# Diseño: interfaz Donda, podcasts y radio explícita

Referencia visual: https://claude.ai/artifact/TKYerEN2DQGov5YL9LfvwJ (variantes «Donda negro» y «Donda blanco»).

## Context

- iPhone es la plataforma principal. macOS e iPad se adaptan con una barra lateral que muestra las mismas tres secciones.
- La app ya tiene un único `AVPlayer` en `AudioPlayerCoordinator`, `PlaybackQueue`, `OfflineDownloadManager`, Core Data con modelo programático (`PersistenceController.makeModel()`) y persistencia de la última posición (`positionPersister`).
- El resolutor ya ejecuta `yt-dlp --flat-playlist` sin shell para la búsqueda alternativa (`resolver.py: search`).

## Decisions

### 1. Tokens Donda en lugar de paletas por tema

`DiegoTheme` expone tokens semánticos que resuelve según `AppThemeMode`:

| Token | `.black` | `.white` |
|---|---|---|
| `background` | `#000000` | `#FFFFFF` |
| `textPrimary` | `#E9E9E9` | `#111111` |
| `textSecondary` | `#666666` | `#8A8A8A` |
| `hairline` | `#1B1B1B` | `#ECECEC` |
| `outline` | `#333333` | `#CFCFCF` |
| `accent` | igual que `textPrimary` | igual que `textPrimary` |

- No hay color de acento: el estado activo se marca invirtiendo el componente (relleno `textPrimary` y texto `background`).
- Tipografía: `Font.system(..., design: .monospaced)` para el texto de interfaz, en mayúsculas con `tracking` de 1,2 a 4 pt. Los títulos usan `.system(...).width(.condensed)` (iOS 16+), con peso regular. No se empaquetan fuentes. *Alternativa descartada*: Archivo Narrow e IBM Plex Mono empaquetadas, porque añaden recursos y `UIAppFonts` y la ganancia visual es mínima.
- Geometría: radio 0 y bordes de 1 pt. La única sombra permitida es la del mini‑player flotante.
- Carátulas: se muestran las carátulas reales a color, cuadradas, sin radio y con borde `hairline` de 1 pt, en listas, tarjetas, mini‑player y reproductor expandido. En el reproductor, la carátula ocupa todo el ancho y «respira» con una sombra mínima mientras suena. Si no hay carátula, se muestra un cuadrado vacío del color de `background`.

### 2. Migración de `AppThemeMode`

`AppThemeMode` queda como `enum { case black, white }` con `colorScheme` `.dark` y `.light`. Al decodificar, `midnight`, `dark`, `system` y cualquier valor desconocido pasan a `.black`, y `light` pasa a `.white`. `SettingsView` muestra un selector de dos opciones.

### 3. Navegación

- `DiegoAppDestination` conserva `.home`, `.search`, `.library` y las rutas de detalle (`artistDetail`, `albumDetail` y la nueva `podcastDetail(channelID:)`). `.browse` y `.radio` se eliminan. `.playlists`, `.songs`, `.albums` y `.artists` dejan de ser pestañas.
- La Biblioteca usa chips segmentados (`LibrarySegment`): Playlists · Podcasts · Canciones · Álbumes · Artistas · Descargas. La selección se recuerda con `@SceneStorage`.
- Ajustes se abre como `sheet` desde un botón de la cabecera de Biblioteca.
- El mini‑player se coloca con `safeAreaInset(edge: .bottom)` sobre `PhoneTabBar`, con 12 pt de margen lateral, borde `outline` y sombra. El contenido se desplaza por debajo y el último elemento queda visible gracias al inset.

### 4. Reproductor expandido

- **Cabecera**: `chevron.down` a la izquierda y un título centrado. En un episodio, el título es el nombre del programa y lleva al detalle. A la derecha quedan Letras (`quote.bubble`, solo en música) y el menú `ellipsis`.
- **Controles de música**: `shuffle`, `previous`, Play/Pause (cuadrado con borde de 1 pt), `next` y `repeat`. Debajo, el botón «Iniciar radio» o «Radio activa · parar», y la cola en filas de texto.
- **Controles de episodio**: botón de velocidad (1×, 1,25×, 1,5×, 1,75×, 2×), −15 s, Play/Pause, +30 s y descarga.
- El halo circular (`CircularHaloScrubber`) se elimina y el progreso pasa a ser un `Slider` lineal de 1 pt.

### 5. Podcasts desde YouTube con cuota mínima

- Un programa es un canal de YouTube. Se sigue desde Buscar (resultado de tipo `.channel`, botón «Seguir»).
- Episodios: `channels.list(part=contentDetails)` → playlist `uploads`, luego `playlistItems.list(maxResults=50)` y `videos.list(part=contentDetails)` para las duraciones, filtrando `durationSeconds >= 2400`. Se pagina hasta reunir 30 episodios o un máximo de 8 páginas, porque canales con muchos clips (The Wild Project) apenas tienen episodios en la primera. Cuesta entre 3 y 17 unidades de cuota por refresco, frente a las 100 de `search.list`. Se guarda en memoria con un TTL de 1 h.
- Primer arranque: se siembran JRE y TWP si `FollowedShow` está vacío. Los IDs de canal se resuelven en tiempo de ejecución con una única búsqueda de canal, para no fijarlos en el código, y se guardan.
- Core Data (migración ligera e inferida):
  - `FollowedShow`: `channelID` (único), `title`, `thumbnailURLString?` y `followedAt`.
  - `EpisodeProgress`: `videoID` (único), `channelID`, `positionSeconds`, `durationSeconds`, `finished` y `updatedAt`.
- Progreso: `positionPersister` se extiende para que, si la pista actual pertenece a un programa seguido o se abrió desde un detalle de podcast (`PlaybackContext.podcast(channelID)`), escriba en `EpisodeProgress` al pausar, cada 15 s y al cambiar de pista. Se marca `finished` cuando quedan 60 s o menos.
- Al reproducir un episodio con `positionSeconds > 0` y sin terminar, se usa `pendingSeekSeconds` antes de reproducir y se muestra «Reanudando en h:mm:ss».
- Velocidad: `player.defaultRate` y `player.rate` solo se aplican a episodios. La música siempre suena a 1×. La velocidad del episodio se guarda en `PlaybackSettings.podcastRate`.
- Controles remotos: con un episodio, `MPRemoteCommandCenter` activa `skipBackwardCommand` (15 s) y `skipForwardCommand` (30 s) y desactiva `next` y `previous`. Con música se hace lo contrario. Now Playing informa `MPNowPlayingInfoPropertyDefaultPlaybackRate`.
- Descargas: se reutiliza `OfflineDownloadManager.enqueue(_:resolver:)` sin cambios de API.

### 6. Radio explícita servida por el resolutor

- Endpoint `GET /v1/radio/{video_id}` (requiere el token de API habitual). Valida `video_id` con la misma regla que `/v1/audio/resolve` y construye él mismo la URL `https://www.youtube.com/watch?v={id}&list=RD{id}`; el cliente nunca envía URLs. Ejecuta `yt-dlp --flat-playlist --dump-single-json --playlist-end 30` sin shell y con el timeout configurado. Devuelve `{ items: [{ id, title, channel, duration_seconds }] }`, quitando la semilla y los IDs que no pasen la validación. Si falla, responde `502` con un mensaje sanitizado.
- Cliente: un `RadioService` con una sola función `func radio(seed: MediaItem) async throws -> [MediaItem]`, sobre `vpsGET`. `AudioPlayerCoordinator.startRadio()` y `stopRadio()` sustituyen la cola posterior a la pista actual. `radioTask` se conserva para cancelar una carga en curso. Se borran `triggerSmartRadioQueue` (y su llamada en `select(_:)`), `fetchRelatedRadio` del protocolo y del servicio, y el stub de `HomeView`.
- *Alternativa descartada*: búsquedas en la Data API, por la mala calidad de los resultados y su coste de cuota.

## Risks / Trade-offs

- **Episodios de 3 h y caché M4A**: puede que el calentamiento en disco del VPS no admita un episodio por `AUDIO_CACHE_MAX_FILE_BYTES`. Como el calentamiento es best-effort, la reproducción sigue en streaming. La descarga offline del cliente usa el stream y no se ve afectada.
- **Mix de YouTube y `yt-dlp`**: un cambio de YouTube puede romper `list=RD…`. Si devuelve una lista vacía, el cliente muestra «Radio no disponible para esta pista» y la cola no cambia.
- **El filtro de 40 min** puede ocultar algún episodio corto. Se acepta.
- **Migración de tema**: quien use Claro pasa a Blanco y el resto a Negro.

## Migration Plan

1. Entidades nuevas de Core Data con migración ligera; sin borrar datos.
2. `AppThemeMode` con decodificación tolerante a los valores antiguos.
3. Desplegar el endpoint de radio en el VPS antes de publicar el cliente. Un cliente antiguo no lo usa.
