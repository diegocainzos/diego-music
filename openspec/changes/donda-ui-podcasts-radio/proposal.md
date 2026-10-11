# Cambio: interfaz Donda, sección de podcasts y radio explícita

## Why

La navegación actual mezcla demasiados destinos: en iPhone hay cinco pestañas (Inicio, Buscar, Biblioteca, Playlists y Ajustes), y en macOS aparecen además `Browse` y `Radio`. La estética Midnight/Bauhaus no convence, y hay inconsistencias de pulido entre pantallas.

El usuario escucha podcasts largos (The Joe Rogan Experience, The Wild Project) y ahora la app no los distingue de la música: no recuerda en qué punto se quedó cada episodio, no tiene velocidad ni saltos, y mezcla los episodios con clips.

La radio está rota por diseño. `AudioPlayerCoordinator.select(_:)` dispara `triggerSmartRadioQueue` en cada reproducción, así que también añade pistas al final de un álbum. Además, `fetchRelatedRadio` hace dos búsquedas `"<artista> music"` y `"<artista> radio"` en la Data API (200 unidades de cuota cada vez) y devuelve vídeos, directos y duplicados.

Dirección visual elegida: **Donda**. Mockup interactivo de referencia: https://claude.ai/artifact/TKYerEN2DQGov5YL9LfvwJ

## What Changes

- **Sistema de diseño Donda**: monocromo absoluto, tipografía condensada y monoespaciada en mayúsculas pequeñas, sin radios ni sombras decorativas. **BREAKING**: `AppThemeMode` pasa a tener solo `.black` (por defecto) y `.white`; desaparecen Midnight, Oscuro, Claro y Sistema, y los valores guardados se migran.
- **Navegación de 3 pestañas**: Inicio, Buscar y Biblioteca. Playlists, Canciones, Álbumes, Artistas, Descargas y Podcasts pasan a ser segmentos de Biblioteca. Ajustes se abre desde la cabecera de Biblioteca. Se eliminan los destinos `.browse` y `.radio`.
- **Mini‑player flotante**: con el reproductor minimizado, la tarjeta flota sobre el contenido, por encima de la barra de pestañas.
- **Reproductor expandido Donda**: sustituye al halo circular. Tiene controles distintos para música y para episodio.
- **Podcasts vía YouTube**: seguir canales desde Buscar (JRE y TWP vienen sembrados), ver solo episodios completos (≥ 40 min), retomar cada episodio donde se dejó, velocidad de 1× a 2×, saltos de −15 s y +30 s, y descarga offline.
- **Radio explícita y aislada**: solo arranca con el botón «Iniciar radio». El VPS devuelve la lista Mix de YouTube (`RD<videoId>`) mediante un endpoint nuevo `GET /v1/radio/{video_id}`. **BREAKING**: se eliminan la radio automática y `fetchRelatedRadio`.
- Inicio **no** muestra «Nuevos episodios».

## Capabilities

### New Capabilities

- `donda-design-system`: tokens, tipografía, temas negro/blanco y componentes base.
- `app-navigation`: tres pestañas, Biblioteca segmentada, mini‑player flotante y reproductor expandido.
- `podcasts`: seguir programas, listar episodios completos, progreso por episodio, controles de episodio y descargas.
- `explicit-radio`: radio bajo demanda basada en el Mix de YouTube y servida por el resolutor.

### Modified Capabilities

- Sustituye a `smart-autoplay-queue` en lo relativo a la radio automática. `enqueueNext` se conserva.
- Sustituye las secciones «Sistema de Diseño y Reproductor» de `AGENTS.md`: halo circular, `AppThemeMode` con Midnight y Bauhaus Hi‑Fi.

## Non-goals

- RSS, Spotify o cualquier fuente de podcasts que no sea YouTube.
- Notificaciones de episodios nuevos o una bandeja de «Nuevos episodios».
- Cambios en autenticación, CarPlay o letras, más allá de reestilizarlos.
- Fuentes tipográficas empaquetadas: se usan las variantes del sistema.

## Impact

- Swift: `Design/DesignSystem.swift`, `Core/Persistence/PlaybackSettings.swift`, `Core/Persistence/PersistenceController.swift`, `Core/Persistence/LibraryStore.swift`, `App/NavigationState.swift`, `App/RootView.swift`, `Features/Home/*`, `Features/Library/*`, `Features/Search/*`, `Features/Player/PlayerDock.swift`, `Features/Settings/SettingsView.swift`, `AudioPlayer/AudioPlayerCoordinator.swift`, `YouTube/YouTubeDataService.swift`, `YouTube/YouTubeEndpoint.swift`. Nuevo `Features/Podcasts/`.
- Core Data: nuevas entidades `FollowedShow` y `EpisodeProgress`, con migración ligera.
- Resolver: nuevo endpoint `GET /v1/radio/{video_id}` en `ResolverService/app/main.py` y método `radio()` en `resolver.py`.
- Documentación: `AGENTS.md` y `README.md`.
