## Context

El resolutor actual crea sesiones opacas con TTL, pero cada `POST /resolve` ejecuta un proceso nuevo de `yt-dlp` y cada token solo reutiliza la URL dentro de una reproducción. AVPlayer mantiene un buffer transitorio, no una caché reutilizable. En local y VPS, los bytes se retransmiten desde Googlevideo en cada reproducción.

La extensión debe conservar el límite de confianza: el cliente nunca recibe la URL upstream, el servicio solo acepta `videoId`, los archivos tienen nombres derivados de IDs validados y ningún token aparece en logs. El contenedor continuará con rootfs read-only; solo un volumen dedicado será escribible.

## Goals / Non-Goals

**Goals:**

- Evitar procesos `yt-dlp` repetidos mientras una resolución siga vigente.
- Deduplicar solicitudes concurrentes del mismo vídeo tanto en servidor como en cliente.
- Reutilizar descriptores opacos válidos y recuperarse de sesiones desaparecidas.
- Preparar la siguiente pista mientras suena la actual.
- Conservar M4A completos en un volumen persistente con límite LRU y servirlos con Range.
- No retrasar la primera reproducción esperando a completar la caché de disco.
- Funcionar igual en Docker local y VPS.

**Non-Goals:**

- Reproducción offline desde almacenamiento del iPhone.
- Persistir resoluciones firmadas más allá de su expiración.
- Cachear formatos distintos de M4A/AAC.
- Compartir el volumen entre múltiples réplicas o VPS sin almacenamiento coordinado.
- Garantizar que toda canción pueda descargarse o permanecer indefinidamente.

## Decisions

### Decorador de resolución LRU y single-flight

`CachingAudioResolver` envolverá `YTDLPResolver`. Una `OrderedDict` indexada por `videoId` guardará `ResolvedAudio` hasta el mínimo entre TTL configurado y expiración upstream menos margen. Un `asyncio.Lock` por ID hará que solicitudes simultáneas compartan una única ejecución. El límite predeterminado será 500 entradas y tres horas.

La caché no se persiste: una URL firmada tiene vida corta y el volumen M4A ya cubre reutilización entre reinicios.

### Caché M4A persistente en background

`PersistentAudioCache` almacenará `<videoId>.m4a` bajo un directorio configurado. Tras un resolve no presente en disco, se programará una única descarga completa background usando la URL/cabeceras internas. La primera sesión seguirá apuntando al upstream y podrá empezar inmediatamente.

La descarga escribirá un `.part` aleatorio, impondrá límite de tamaño, verificará que recibió bytes, hará `os.replace` atómico y actualizará mtime como marca LRU. Al superar el límite global eliminará los M4A menos recientes. Fallos o cancelaciones borrarán temporales y no afectarán la reproducción activa.

En un hit de disco no se ejecutará `yt-dlp`: se creará una sesión opaca cuya fuente es el archivo. Además, cada petición de stream comprobará si el M4A terminó de calentarse, de modo que un token emitido originalmente para upstream cambia a disco sin esperar un resolve nuevo. `FileResponse` de Starlette proporcionará HEAD, Range simple/múltiple, 206 y 416.

### Volumen Docker dedicado

Compose montará un volumen `audio_cache` en `/var/cache/diegomusic`. La ruta existirá con propietario UID 10001 dentro de la imagen y seguirá siendo escribible aunque el rootfs sea read-only. `AUDIO_CACHE_MAX_BYTES=5368709120` limitará el volumen a 5 GiB por defecto; cero deshabilitará la persistencia.

### Caché cliente actor y contrato de invalidación

`AudioResolverClient` pasará a ser actor y mantendrá descriptores por `videoId` hasta `expiresAt` menos 90 segundos. Un diccionario de `Task` compartirá solicitudes concurrentes. El protocolo añadirá `invalidate(videoID:)`; la implementación no configurada usará no-op.

Si AVPlayer falla al abrir una sesión, `AudioPlayerCoordinator` invalidará el descriptor y realizará un único resolve/reintento automático. Un segundo fallo se muestra al usuario, evitando bucles.

### Precarga de la cola

El coordinador observará `items/currentIndex` y resolverá en background solo la pista siguiente. El cliente cacheará el descriptor y el servidor iniciará también el calentamiento M4A. Cambios de cola cancelarán la tarea de prefetch anterior. La precarga nunca reemplazará el AVPlayer activo ni mostrará errores.

### Diagnóstico sin material sensible

La respuesta de resolve incorporará un campo `cacheStatus` opcional (`disk`, `resolution`, `miss`) para pruebas/diagnóstico, sin URLs internas. El cliente lo ignorará funcionalmente. No se añadirán access logs.

## Risks / Trade-offs

- [La primera reproducción duplica tráfico por streaming y descarga background] → limitar a una descarga por ID y permitir desactivar caché de disco con tamaño cero.
- [El volumen llena el VPS] → límite en bytes, LRU después de cada escritura y configuración explícita.
- [Una sesión cliente sobrevive a un reinicio del servidor] → invalidación y un único reintento automático.
- [El archivo es eliminado mientras se reproduce] → tocar mtime en cada resolve; si aun así falla, el reintento reconstruye la sesión.
- [Dos workers no comparten locks/memoria] → ejecutar un worker en este alcance; el volumen usa reemplazos atómicos.
- [Prefetch consume datos de canciones que el usuario no escucha] → precargar solo una pista y permitir deshabilitarlo posteriormente.
- [Archivos parciales por caída] → sufijo `.part`, limpieza al arrancar y `os.replace` tras éxito.

## Migration Plan

1. Añadir caché de resolución y pruebas sin activar disco.
2. Añadir almacenamiento persistente, proxy de archivos y volumen Compose.
3. Añadir caché/invalidation en Swift y pruebas.
4. Añadir prefetch y reintento del coordinador.
5. Reconstruir contenedores y validar miss → resolution/disk hit, Range y reinicio.
6. Desplegar en VPS; el rollback consiste en retirar el volumen/config y volver al commit anterior.

## Open Questions

- Ajustar el límite de 5 GiB según almacenamiento y uso real del VPS.
- Evaluar métricas agregadas de hits/misses en un cambio futuro sin activar access logs.
