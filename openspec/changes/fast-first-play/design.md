## Decisiones

1. **Reutilizar la extracción.** `YTDLPResolver.resolve` añade a `ResolvedAudio` el campo `download_info: bytes | None` (`repr=False`, `compare=False`). Es el JSON de `--dump-single-json` sin las claves `formats`, `requested_formats`, `thumbnails`, `automatic_captions`, `subtitles`, `heatmap` ni `description` (~7 KB). Contiene la URL upstream, así que nunca se registra ni se devuelve, y solo vive en memoria del proceso y en un archivo temporal `0600`.
2. **Descarga con `--load-info-json`.** `PersistentAudioCache.schedule(video_id, info=None)`. Con `info`, `_download` lo escribe con `tempfile.mkstemp(dir=info_directory)` (por defecto el tmpfs `/tmp`) y ejecuta `yt-dlp --no-warnings --quiet --no-cache-dir --fixup never --load-info-json <tmp> -o <tpl> --force-overwrites`. El temporal se borra en `finally`. Sin `info` (acierto de caché de resolución o `schedule` desde `proxy_audio`) se hace la descarga completa con `-f "bestaudio[ext=m4a][acodec^=mp4a]/bestaudio[ext=m4a]"`, la misma selección que la resolución, también sin `-x`.
3. **Un único ffmpeg.** `_defragment` sigue siendo el único postproceso; `yt-dlp` ya no recibe `--ffmpeg-location`.
4. **Semáforo de 2.** `_download` adquiere un `asyncio.Semaphore(2)` antes de lanzar procesos. Las tareas encoladas siguen siendo cancelables y deduplicadas por `videoId`.
5. **Caché de resolución sin info.** `CachingAudioResolver` guarda `dataclasses.replace(audio, download_info=None)`: 500 entradas × ~7 KB serían RAM permanente innecesaria.
6. **Precalentamiento en el cliente.** `AudioPlayerCoordinator.warm(_ items: [MediaItem])` cancela el precalentamiento anterior y resuelve en serie como máximo 2 pistas que no sean la actual. Es especulativo: los errores se ignoran y nunca cambia la cola ni la pista actual. `AlbumView` lo llama cuando el álbum termina de cargar y `ListaView` al aparecer.

## Alternativa descartada

Servir upstream de inmediato sin esperar a la descarga: Googlevideo rechaza rangos grandes (403) y el fMP4 duplica la duración en AVFoundation. `proxy_audio` mantiene la espera acotada de 30 s, que ahora rara vez supera 2 s.
