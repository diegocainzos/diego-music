## ADDED Requirements

### Requirement: Caché de resolución por vídeo
El servicio SHALL reutilizar una resolución vigente por `videoId`, SHALL limitar entradas mediante LRU y SHALL expirar cada entrada antes que su URL upstream.

#### Scenario: Repetición durante el TTL
- **WHEN** se resuelve dos veces el mismo vídeo antes de expirar
- **THEN** el servicio ejecuta `yt-dlp` una sola vez y crea sesiones opacas válidas para ambas respuestas

#### Scenario: Resolución expirada
- **WHEN** la entrada alcanzó su TTL efectivo
- **THEN** el siguiente resolve ejecuta nuevamente el adaptador upstream

#### Scenario: Solicitudes simultáneas
- **WHEN** varias solicitudes concurrentes resuelven el mismo vídeo ausente
- **THEN** todas comparten una única ejecución y ninguna recibe la URL upstream

### Requirement: Caché persistente M4A
El servicio SHALL descargar en background una pista compatible después del primer resolve, SHALL escribirla atómicamente en un directorio controlado y SHALL reutilizarla entre reinicios.

#### Scenario: Primera reproducción
- **WHEN** la pista no existe en disco
- **THEN** el servicio devuelve inmediatamente una sesión upstream y programa una sola descarga sin esperar su finalización

#### Scenario: Reproducción posterior desde disco
- **WHEN** existe un M4A completo para el `videoId`
- **THEN** el servicio crea una sesión de archivo sin ejecutar `yt-dlp` ni contactar Googlevideo para reproducirla

#### Scenario: Sesión emitida durante el calentamiento
- **WHEN** una sesión upstream sigue vigente y el M4A termina de almacenarse
- **THEN** el mismo token opaco sirve las siguientes peticiones Range desde disco sin exigir un resolve nuevo

#### Scenario: Descarga fallida
- **WHEN** el origen rechaza o interrumpe la descarga
- **THEN** el servicio elimina el temporal y conserva funcionamiento upstream sin publicar detalles sensibles

### Requirement: Límite LRU de almacenamiento
La caché persistente SHALL respetar un máximo configurable de bytes y SHALL eliminar primero archivos completos menos recientemente utilizados.

#### Scenario: Límite superado
- **WHEN** una escritura completa hace superar el límite
- **THEN** se eliminan entradas antiguas hasta volver al límite sin tocar temporales activos

#### Scenario: Caché deshabilitada
- **WHEN** el máximo configurado es cero
- **THEN** no se programan descargas ni se requiere un directorio escribible

### Requirement: Reproducción Range desde archivo
Las sesiones de disco SHALL soportar HEAD y peticiones Range con los mismos estados y cabeceras necesarios para AVPlayer.

#### Scenario: Rango válido cacheado
- **WHEN** AVPlayer solicita un rango de un archivo existente
- **THEN** el servicio responde 206 con bytes, Content-Range, Content-Length y Accept-Ranges correctos

#### Scenario: Rango fuera de límites
- **WHEN** AVPlayer solicita bytes que no existen
- **THEN** el servicio responde 416 con el tamaño total

### Requirement: Caché de descriptor en el cliente
DiegoMusic SHALL reutilizar descriptores opacos por vídeo hasta un margen anterior a su expiración y SHALL deduplicar solicitudes concurrentes.

#### Scenario: Descriptor vigente
- **WHEN** se solicita de nuevo una canción con descriptor vigente
- **THEN** el cliente lo devuelve sin realizar otra petición HTTP

#### Scenario: Descriptor próximo a expirar
- **WHEN** faltan menos de 90 segundos para su expiración
- **THEN** el cliente lo descarta y solicita uno nuevo

#### Scenario: Invalidación explícita
- **WHEN** el reproductor informa que la sesión no puede abrirse
- **THEN** el cliente elimina el descriptor correspondiente

### Requirement: Recuperación automática de sesión
El reproductor SHALL reintentar una vez una pista después de invalidar su descriptor y SHALL evitar ciclos ilimitados.

#### Scenario: Sesión perdida por reinicio
- **WHEN** AVPlayer falla al abrir un descriptor cacheado y el siguiente resolve funciona
- **THEN** la reproducción continúa automáticamente con la nueva sesión

#### Scenario: Segundo fallo
- **WHEN** también falla el descriptor renovado
- **THEN** el reproductor detiene el reintento y muestra un error sanitizado

### Requirement: Precarga de siguiente pista
DiegoMusic SHALL resolver silenciosamente solo la siguiente entrada de la cola mientras la pista actual está activa.

#### Scenario: Siguiente disponible
- **WHEN** existe una pista posterior al índice actual
- **THEN** se solicita en background sin modificar AVPlayer ni el estado visual de la pista actual

#### Scenario: Cola modificada
- **WHEN** cambia la siguiente entrada antes de finalizar el prefetch
- **THEN** se cancela la tarea anterior y se prepara la nueva siguiente pista

#### Scenario: Fallo de prefetch
- **WHEN** la resolución anticipada falla
- **THEN** el error no interrumpe la reproducción actual y se reintentará al seleccionar la pista
