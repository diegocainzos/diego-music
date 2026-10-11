## Why

Una canción nueva tarda unos 13 s en empezar a sonar. El resolutor ejecuta `yt-dlp` dos veces por pista: una para resolver (unos 5,5 s de extracción) y otra para descargar la caché M4A, que **repite la extracción completa**. Después hace dos pasadas de ffmpeg (`-x --audio-format m4a` más el remux). `proxy_audio` espera a esa descarga antes de servir. Cada `yt-dlp` extra (Python más Deno) es además el mayor pico de RAM del VPS.

Lo medido en local con `yt-dlp 2026.07.04`: extracción 5,5 s; descarga con `--load-info-json` (JSON recortado de 7 KB) 1,4 s; remux 0,07 s.

## What Changes

- La resolución conserva un JSON de información recortado (sin `formats`, `thumbnails`, subtítulos, `heatmap` ni `description`) y se lo entrega a la descarga en segundo plano. Esta usa `yt-dlp --load-info-json`, sin volver a extraer.
- La descarga no convierte (`-x`/`--audio-format` desaparecen y se añade `--fixup never`). El único postproceso es el remux progresivo propio, de una sola pasada de ffmpeg.
- Máximo de 2 descargas simultáneas (semáforo) para acotar la RAM.
- La caché de resolución en memoria nunca guarda el JSON de información.
- El cliente precalienta las 2 primeras pistas al abrir un álbum o una playlist, reutilizando `resolve` (que programa la descarga).

## Capabilities

### New Capabilities
- `fast-first-play`: arranque rápido de pistas no cacheadas y uso de RAM acotado en el resolutor.

## Impact

- `ResolverService/app/resolver.py`, `resolution_cache.py`, `audio_cache.py`, `main.py` y sus tests.
- `DiegoMusic/AudioPlayer/AudioPlayerCoordinator.swift`, `Features/Home/AlbumView.swift`, `Features/Library/ListaView.swift`.
- Se mantienen los invariantes: solo `yt-dlp` descarga, nunca se sirve un archivo parcial y las URLs upstream no salen del servicio.
