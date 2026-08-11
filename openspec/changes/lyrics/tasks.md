## 1. Modelos y servicio de letras

- [x] 1.1 Añadir `DiegoMusic/Lyrics/LyricsModels.swift`: modelos `LyricsLine` (startTime, endTime, text) y `LyricSegment`.
- [x] 1.2 Añadir `DiegoMusic/Lyrics/LyricsService.swift`: protocolo `LyricsProviding` (consuma `MediaItem` + tiempo) y proveedor local/experimental por defecto que devuelve ejemplos embebidos etiquetados o `nil`.

## 2. Vista de letras sincronizadas

- [x] 2.1 Añadir `DiegoMusic/Lyrics/LyricsView.swift`: consume `LyricsProviding` y el tiempo de reproducción, resalta y auto‑desplaza la línea activa.
- [x] 2.2 Estado vacío claro cuando no hay letra o proveedor, sin interrumpir la reproducción.

## 3. Accesibilidad

- [x] 3.1 VoiceOver anuncia la línea actual; respetar `accessibilityReduceMotion` (salto directo sin animación continua) y mantener contraste legible.

## 4. Validación e integración

- [x] 4.1 Validar el cambio OpenSpec estricto (`openspec validate lyrics --type change --strict`).
- [x] 4.2 Regenerar el proyecto (XcodeGen) si hay ficheros nuevos y documentar el seam `LyricsProviding`/`LyricsView` para que `player-experience` (C1) lo integre en el reproductor ampliado tras el merge.
