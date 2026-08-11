# Cambio: cola automática inteligente y encolado prioritario

## Why

Cuando el usuario selecciona una canción desde la búsqueda o el inicio, la lista de reproducción actual se limita a esa única pista o a las canciones visibles en pantalla. Al terminar la pista, la música se detiene. Para ofrecer una experiencia de reproducción fluida e idéntica a YouTube Music, es necesario generar automáticamente una radio/cola inteligente (~15 pistas) basada en el artista y artistas afines del mismo género/época, además de permitir insertar manualmente pistas al principio de la cola posterior (Play Next).

## What Changes

- **Radio Autoproducida / Smart Auto-Queue**: Al reproducir un `MediaItem`, se dispara una carga asíncrona de fondo que busca canciones top del artista actual y de artistas afines/género equivalente (~15 temas en total) y los añade a `PlaybackQueue` sin interrumpir el tema sonando.
- **Encolado prioritario (`enqueueNext`)**: Añadir el método `enqueueNext(_ item: MediaItem)` a `PlaybackQueue` para insertar el nuevo ítem inmediatamente después de la pista en reproducción actual (`currentIndex + 1`), desplazando el resto de la cola automática.
- **Integración en AudioPlayerCoordinator**: Coordinar la auto-generación de la cola cuando el usuario inicia una pista desde búsqueda/inicio de forma transparente.

## Capabilities

### New Capabilities

- `smart-autoplay-queue`: generación automática de colas afines compuestas por temas del artista y de artistas del mismo género/estilo al iniciar una pista, e inserción de pistas en la posición inmediatamente siguiente a la pista activa.

### Modified Capabilities

<!-- No hay baseline archivado. -->

## Impact

- `DiegoMusic/Core/Models/PlaybackQueue.swift`: nuevo método `enqueueNext(_ item: MediaItem)`.
- `DiegoMusic/AudioPlayer/AudioPlayerCoordinator.swift`: soporte para auto-generación de cola mediante servicio de datos.
- `DiegoMusic/YouTube/YouTubeDataService.swift`: método auxiliar o búsqueda combinada para generar sugerencias de radio afín.
