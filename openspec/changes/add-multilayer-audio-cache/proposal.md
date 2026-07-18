## Why

Cada selección ejecuta `yt-dlp` aunque la canción se haya resuelto recientemente, produciendo una espera perceptible y repitiendo transferencia desde Googlevideo. DiegoMusic necesita reutilizar resoluciones y audio ya obtenido, además de preparar la siguiente pista, sin exponer URLs upstream ni perder la recuperación automática ante expiraciones o reinicios.

## What Changes

- Añadir una caché LRU en memoria del resolutor, indexada por `videoId`, con TTL limitado por la expiración upstream y deduplicación de resoluciones concurrentes.
- Añadir una caché persistente M4A en un volumen Docker con límite de bytes, actualización LRU, escritura atómica y reproducción HTTP Range desde disco.
- Descargar en segundo plano el M4A después del primer resolve sin retrasar el inicio de la primera reproducción.
- Añadir una caché en memoria de descriptores opacos en DiegoMusic, con margen de expiración, deduplicación y invalidación explícita.
- Reintentar automáticamente una vez con descriptor nuevo cuando AVPlayer rechace una sesión cacheada o perdida por reinicio del servidor.
- Precargar la siguiente canción de la cola para ocultar resolución y calentamiento de caché durante la reproducción actual.
- Añadir configuración, métricas no sensibles de estado, pruebas de expiración/concurrencia/LRU/rangos y documentación operativa para local y VPS.

## Capabilities

### New Capabilities

- `multilayer-audio-cache`: reutilización coordinada de resoluciones, descriptores cliente y archivos M4A persistentes, con precarga, expiración, límites y recuperación automática.

### Modified Capabilities

<!-- Las capacidades VPS aún viven en cambios no archivados; esta extensión se expresa como capacidad nueva autocontenida. -->

## Impact

- Servicio: configuración, resolución, sesiones, proxy, nuevo almacenamiento persistente y tareas background.
- Despliegue: volumen Docker escribible y límites configurables de caché.
- Cliente: `AudioResolverClient`, contrato de invalidación y `AudioPlayerCoordinator`.
- Pruebas: pytest para single-flight/LRU/descarga/rangos y XCTest para caché cliente/prefetch/reintento.
- Operación: mayor consumo controlado de disco y una descarga adicional en segundo plano durante la primera reproducción.
