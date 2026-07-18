## 1. Caché de resolución del servicio

- [x] 1.1 Añadir configuración validada para TTL, margen y capacidad LRU de resoluciones.
- [x] 1.2 Implementar `CachingAudioResolver` con expiración efectiva, LRU y single-flight por vídeo.
- [x] 1.3 Integrar la caché en `/resolve` y exponer únicamente estado de hit/miss no sensible.
- [x] 1.4 Probar hits, expiración, desalojo y concurrencia sin ejecutar YouTube.

## 2. Caché persistente M4A

- [x] 2.1 Implementar almacenamiento por ID, temporales atómicos, descarga background deduplicada y limpieza de parciales.
- [x] 2.2 Implementar límite de bytes y desalojo LRU preservando archivos en escritura.
- [x] 2.3 Servir sesiones cacheadas con FileResponse y soporte HEAD/Range/416.
- [x] 2.4 Integrar hits de disco antes de `yt-dlp` y calentamiento después de misses sin bloquear la respuesta.
- [x] 2.5 Añadir pruebas de descarga, persistencia, fallos, LRU y rangos cacheados.

## 3. Despliegue y operación

- [x] 3.1 Añadir volumen Docker escribible compatible con rootfs read-only y variables de tamaño/ruta.
- [x] 3.2 Documentar comportamiento local/nube, consumo, limpieza, desactivación y persistencia del volumen.
- [x] 3.3 Construir y probar el contenedor con miss, hit de resolución, hit de disco y reinicio.

## 4. Caché y precarga del cliente

- [x] 4.1 Convertir `AudioResolverClient` en actor con caché de descriptores, margen de expiración y single-flight.
- [x] 4.2 Extender el protocolo con invalidación y cubrir cache hit, expiración, concurrencia e invalidación con XCTest.
- [x] 4.3 Implementar un único reintento automático de AVPlayer tras invalidar una sesión fallida.
- [x] 4.4 Observar la cola y precargar silenciosamente la siguiente pista con cancelación al cambiar.

## 5. Validación final

- [x] 5.1 Ejecutar pytest, pruebas Swift macOS, build iOS Simulator, escáner de secretos y OpenSpec estricto.
- [x] 5.2 Verificar que no se registran ni retornan URLs upstream, tokens o rutas internas.
- [x] 5.3 Committear la implementación con el worktree limpio preservando los ajustes de firma locales existentes.
