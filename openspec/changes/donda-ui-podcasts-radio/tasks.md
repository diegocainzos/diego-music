# Tareas: interfaz Donda, podcasts y radio explícita

## 1. Radio explícita (aislada, primero)

- [ ] 1.1 Resolver: `ResolverService.radio(video_id)` en `resolver.py` (yt-dlp `--flat-playlist --playlist-end 30`, sin shell, con timeout) y `GET /v1/radio/{video_id}` en `main.py` con validación de ID, modelos de respuesta y errores sanitizados.
- [ ] 1.2 Resolver: tests con un `yt-dlp` falso para salida válida, ID inválido (422), fallo y timeout (502) y exclusión de la semilla.
- [ ] 1.3 Cliente: `RadioService.radio(seed:)` sobre `vpsGET`; `AudioPlayerCoordinator.startRadio()` y `stopRadio()`; quitar `triggerSmartRadioQueue` de `select(_:)`, y borrar `fetchRelatedRadio` del protocolo, del servicio y del stub de `HomeView`.
- [ ] 1.4 Tests: reproducir un álbum no añade pistas; `startRadio` reemplaza solo la cola posterior; si la radio falla, la cola no cambia.

## 2. Sistema de diseño Donda

- [ ] 2.1 `AppThemeMode { black, white }` con decodificación de valores antiguos y test de migración.
- [ ] 2.2 `DiegoTheme`: tokens Donda, tipografía del sistema monoespaciada y condensada, y modificadores `dondaLabel` y `dondaTitle`; eliminar los tokens Midnight y Bauhaus que queden sin uso.
- [ ] 2.3 `SettingsView`: selector de dos opciones, Negro y Blanco.

## 3. Navegación

- [ ] 3.1 `DiegoAppDestination`: quitar `.browse` y `.radio`; añadir `.podcastDetail(channelID:)`; `PhoneTabBar` con 3 pestañas; barra lateral de macOS con las mismas 3 secciones.
- [ ] 3.2 Biblioteca segmentada (Playlists, Podcasts, Canciones, Álbumes, Artistas, Descargas) reutilizando las vistas actuales, y Ajustes en `sheet`.
- [ ] 3.3 Inicio: Continuar, Escuchado hace poco y Tus podcasts; sin «Nuevos episodios».
- [ ] 3.4 Mini‑player flotante con `safeAreaInset` sobre la barra de pestañas.
- [ ] 3.5 `PlayerDock` reescrito al estilo Donda: quitar `CircularHaloScrubber`, `Slider` lineal y controles de música y de episodio.

## 4. Podcasts

- [ ] 4.1 Core Data: entidades `FollowedShow` y `EpisodeProgress` en `makeModel()` y operaciones en `LibraryStore`, con tests en memoria.
- [ ] 4.2 `YouTubeDataService`: `uploadsPlaylistID(channelID:)` y `episodes(channelID:)` con filtro de 40 min o más y caché de 1 h; tests con transporte falso.
- [ ] 4.3 Siembra de JRE y TWP si no hay programas seguidos.
- [ ] 4.4 Buscar: botón Seguir en resultados de canal; `PodcastDetailView` con episodios, progreso, descarga y aviso de clips ocultos.
- [ ] 4.5 Progreso por episodio con `positionPersister` y `PlaybackContext.podcast`, reanudación con `pendingSeekSeconds` y aviso «Reanudando en…».
- [ ] 4.6 Velocidad (`defaultRate`, solo episodios, guardada en `PlaybackSettings.podcastRate`), saltos de −15 s y +30 s, y cambio de comandos remotos entre música y episodio.
- [ ] 4.7 Descarga de episodios con `OfflineDownloadManager` y su aparición en Biblioteca › Descargas.

## 5. Documentación y validación

- [ ] 5.1 Actualizar `AGENTS.md` (sistema de diseño, reproductor y radio) y `README.md`.
- [ ] 5.2 Marcar `smart-autoplay-queue` como sustituido en lo relativo a la radio automática.
- [ ] 5.3 `./scripts/generate-project.sh`, tests de macOS, `build-for-testing` de iOS, `./scripts/validate-resolver.sh`, `./scripts/verify-no-secrets.py` y `openspec validate donda-ui-podcasts-radio --type change --strict`.
- [ ] 5.4 iPhone físico: pantalla bloqueada con episodio (saltos de 15/30 s y velocidad), auriculares y reanudación tras cerrar la app.
