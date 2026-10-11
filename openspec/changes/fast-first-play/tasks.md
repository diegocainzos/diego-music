## 1. Resolutor

- [x] 1.1 `ResolvedAudio.download_info` y recorte del JSON en `YTDLPResolver.resolve`
- [x] 1.2 `CachingAudioResolver` guarda entradas sin `download_info`
- [x] 1.3 `PersistentAudioCache.schedule(video_id, info)` con `--load-info-json`, temporal `0600` borrado en `finally`
- [x] 1.4 Descarga sin `-x`/`--audio-format`/`--ffmpeg-location`, con `--fixup never`
- [x] 1.5 Semáforo de 2 descargas simultáneas
- [x] 1.6 `resolve_audio` pasa `audio.download_info` a `schedule`
- [x] 1.7 Tests: comando con `--load-info-json`, borrado del temporal, caché sin info, límite de concurrencia, un único ffmpeg

## 2. Cliente

- [x] 2.1 `AudioPlayerCoordinator.warm(_:)` (máx. 2 pistas, cancelable, errores ignorados)
- [x] 2.2 Llamadas desde `AlbumView` y `ListaView`
- [x] 2.3 Test de `warm` con resolver falso

## 3. Verificación

- [x] 3.1 Suite del resolutor, tests macOS y build iOS
- [ ] 3.2 En el VPS: una pista nueva suena en ≤ 8 s y su `.m4a` aparece en el volumen
