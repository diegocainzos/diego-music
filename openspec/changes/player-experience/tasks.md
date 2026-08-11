## 1. Modos de reproducción (shuffle / repeat)

- [x] 1.1 Definir un modelo de estado `PlaybackMode`/`RepeatMode` (shuffle, repeat `off`/`all`/`one`) y exponerlo publicado desde `AudioPlayerCoordinator` o un objeto observable auxiliar.
- [x] 1.2 Implementar repeat `one` (recargar la misma pista al final) y repeat `all` (reiniciar la cola y continuar) en `AudioPlayerCoordinator`.
- [x] 1.3 Implementar shuffle como permutación de índices sin duplicados, conservando la pista activa y restaurando el orden al desactivar.
- [x] 1.4 Añadir controles conmutables de shuffle y repeat en `PlayerDock` con etiquetas accesibles y área ≥ 44pt.

## 2. Cola reordenable por arrastre

- [x] 2.1 Añadir reordenación por arrastre al editor de cola (`queueEditor`) llamando a `queue.move(from:to:)`, conservando flechas de subir/bajar accesibles.

## 3. Continuar donde lo dejaste

- [x] 3.1 Persistir pista activa + `currentTime` vía `PlaybackSettings`/`LibraryStore` de forma periódica y en pausa, gated por ajuste.
- [x] 3.2 Restaurar pista + posición al arrancar desde `AppEnvironment`/`DiegoMusicApp`, en pausa y respetando el ajuste.
- [x] 3.3 Exponer un ajuste "continuar donde lo dejaste" en `SettingsView`/`PlaybackSettings`.

## 4. Gestos del reproductor ampliado

- [x] 4.1 Añadir swipe horizontal para siguiente/anterior sobre la carátula del ampliado.
- [x] 4.2 Añadir arrastre hacia abajo para contraer el ampliado, respetando `accessibilityReduceMotion`.
- [x] 4.3 Mantener o introducir botones de control grandes (≥ 44pt) con etiquetas accesibles.

## 5. Autoplay/radio con proveedor inyectado

- [x] 5.1 Definir el protocolo `RelatedTrackProviding` (inyectado, opcional) e inyectarlo en `AudioPlayerCoordinator`.
- [x] 5.2 Al terminar la cola con repeat `off`, pedir una pista relacionada y encolarla/reproducirla como best-effort.

## 6. Validación

- [x] 6.1 Regenerar el proyecto si hay ficheros nuevos (`.pi/tools/xcodegen/bin/xcodegen` o `./scripts/generate-project.sh`) y ejecutar validaciones Swift en máquina con Xcode (este entorno es Linux, sin compilador Swift).
- [x] 6.2 Validar el cambio OpenSpec estricto y revisar que la accesibilidad se ha preservado (labels, reduce motion, áreas ≥ 44pt).
