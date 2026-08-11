# Diseño: Cola automática inteligente y encolado prioritario

## Arquitectura de Solución

1. **PlaybackQueue (`enqueueNext`)**:
   - `enqueueNext(_ item: MediaItem)`: inserta `item` en `items` en la posición `(currentIndex ?? 0) + 1`. Si la pista ya existía en la cola, la mueve a esa posición. Ajusta los punteros de shuffle si está activo.

2. **Smart Radio Queue Generation (`AudioPlayerCoordinator` / `YouTubeDataService`)**:
   - Al invocar `play(item)` o `playQueue([item])`, se activa una tarea en segundo plano `generateSmartQueue(for: item)`.
   - Se consulta a `YouTubeDataService`:
     - Pistas top del canal/artista (`item.channelTitle`).
     - Búsqueda combinada de artistas afines y estilo (50% artista, 50% relacionados).
   - Los elementos obtenidos se añaden progresivamente a `PlaybackQueue.enqueue(item)` omitiendo duplicados.

3. **Invariantes**:
   - La reproducción actual nunca se detiene ni salta mientras se carga la cola inteligente.
   - El encolado prioritario (`enqueueNext`) sitúa la pista inmediatamente después de la pista en reproducción para reproducirse al finalizar la pista actual.
