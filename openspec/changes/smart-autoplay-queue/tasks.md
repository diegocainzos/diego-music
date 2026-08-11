# Tareas — Cola automática inteligente y encolado prioritario

## 1. PlaybackQueue: Encolado prioritario

- [x] 1.1 Implementar `enqueueNext(_ item: MediaItem)` en `DiegoMusic/Core/Models/PlaybackQueue.swift` e incluir pruebas unitarias para inserción en `currentIndex + 1` y reordenamiento de duplicados.

## 2. YouTubeDataService: Servicio de Radio Inteligente

- [x] 2.1 Añadir método `fetchRelatedRadio(for item: MediaItem) async throws -> [MediaItem]` en `YouTubeDataServicing` y `YouTubeDataService` que combine pistas del artista y artistas afines.

## 3. AudioPlayerCoordinator: Integración de Auto-Queue

- [x] 3.1 Integrar `generateSmartQueue(for: item)` en `AudioPlayerCoordinator` para disparar la carga silenciosa en segundo plano al reproducir un nuevo tema.

## 4. Validación

- [x] 4.1 Ejecutar pruebas unitarias de `PlaybackQueue` y `AudioPlayerCoordinator`.
- [x] 4.2 Validar el cambio OpenSpec mediante `.pi/openspec/node_modules/.bin/openspec validate smart-autoplay-queue --type change --strict`.
