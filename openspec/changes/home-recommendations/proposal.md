## Why

Faltan tres cosas en el uso diario:
- No hay forma de guardar en favoritos la canción que suena desde el reproductor.
- Los podcasts solo muestran las ~30–50 entregas más recientes (JRE: 2563 → 2519).
- Inicio no propone nada basado en lo que escucha el usuario.

## What Changes

- **Reproductor expandido:** botón corazón (solo música) que alterna `FavoriteTrack` y se actualiza al instante.
- **Detalle de podcast:** botón «CARGAR MÁS EPISODIOS» que continúa la playlist de uploads con el `nextPageToken` de la página anterior. Solo la primera página se cachea.
- **Inicio «PARA TI»:** el cliente envía hasta 20 escuchas recientes (título y canal) a `POST /v1/recommendations`.
  - El resolutor pide 10 canciones a OpenRouter (`OPENROUTER_API_KEY`, modelo `OPENROUTER_MODEL`, por defecto `openrouter/free`).
  - Cada sugerencia se convierte en un vídeo con `ytsearch1` de yt-dlp (como máximo 2 a la vez). No gasta cuota de la Data API.
  - El cliente recuerda el resultado mientras el historial no cambie.

## Capabilities

### New Capabilities
- `home-recommendations`: favorito desde el reproductor, paginación de episodios y recomendaciones de Inicio por LLM.

## Impact

- **Swift:** `PlayerDock`, `PodcastDetailView`, `YouTubeDataService`, `HomeView` y `HomeViewModel`. `PodcastEpisodePage` gana `nextPageToken`.
- **Resolutor:** `app/recommendations.py`, la ruta `/v1/recommendations` y la configuración de OpenRouter.
- **Seguridad:** la clave de OpenRouter vive solo en `ResolverService/.env`, nunca en el cliente. Los errores del LLM se devuelven sanitizados.
