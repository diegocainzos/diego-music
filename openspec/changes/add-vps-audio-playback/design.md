## Context

DiegoMusic usa actualmente YouTube Data API para catálogo y un `WKWebView` con YouTube IFrame para reproducción. El coordinador está acoplado al ciclo de vida de la vista y el dock crea superficies web distintas para sus estados compacto y ampliado. La nueva rama conservará el catálogo y la persistencia, pero trasladará la resolución de la pista a un servicio privado y la reproducción a AVFoundation.

El cliente debe ejecutarse en iOS 17 y macOS 13. El servicio debe poder desplegarse en un VPS pequeño, no aceptar URLs arbitrarias y no revelar al cliente URLs upstream ni material de autenticación utilizado por `yt-dlp`.

## Goals / Non-Goals

**Goals:**

- Reproducir representaciones de audio YouTube compatibles mediante `AVPlayer` sin crear una superficie de vídeo.
- Mantener la cola, favoritos, playlists, historial y búsqueda existentes.
- Continuar la reproducción en segundo plano en iPhone y exponer controles del sistema.
- Proporcionar un resolutor autenticado y desplegable en Docker con proxy HTTP Range.
- Hacer explícitos y recuperables los estados de carga, expiración, indisponibilidad y error.
- Mantener todas las credenciales fuera de Git y evitar filtrarlas en respuestas o logs.

**Non-Goals:**

- Descargar o conservar archivos multimedia permanentemente.
- Resolver contenido DRM, privado o no disponible para la identidad configurada en el VPS.
- Transcodificar en el primer incremento formatos sin una representación M4A/AAC compatible.
- Ofrecer el resolutor como proxy público o multiusuario.
- Distribuir el servicio, cookies o tokens dentro del binario iOS.

## Decisions

### Separar catálogo, resolución y reproducción

YouTube Data API seguirá produciendo `MediaItem` y el `videoId` será la única entrada del resolutor. Un nuevo `AudioResolverClient` solicitará una sesión; `AudioPlayerCoordinator` reproducirá su URL opaca con `AVPlayer`. Esta separación permite actualizar `yt-dlp` en el VPS sin reinstalar la app.

Alternativa descartada: extractor Swift embebido. Evita el servidor, pero obliga a publicar una versión nueva cada vez que cambian firmas, parámetro `n`, clientes o PO tokens.

### FastAPI y `yt-dlp` como proceso sin shell

El servicio será una aplicación Python/FastAPI. Ejecutará `yt-dlp` con una lista fija de argumentos, `--no-playlist`, un selector M4A y una URL construida desde un ID validado de once caracteres. Nunca interpolará una URL suministrada por el cliente ni ejecutará mediante shell. La imagen instalará los extras recomendados de `yt-dlp`, un runtime JavaScript y FFmpeg, aunque el MVP no transcodifique.

Alternativa descartada: librería extractor Node. `yt-dlp` proporciona mejor mantenibilidad operativa, selección de formatos y soporte actualizable.

### Sesiones opacas y proxy con rangos

`POST /v1/audio/resolve` exigirá Bearer token y almacenará en memoria una URL upstream, cabeceras permitidas, MIME y expiración. La respuesta solo contendrá una URL con un token aleatorio de 256 bits. `GET`/`HEAD /v1/audio/stream/{token}` reenviará `Range` y devolverá `Content-Range`, `Content-Length`, `Accept-Ranges` y MIME cuando estén presentes.

El token de stream actúa como una capacidad temporal. No se incluirá la credencial API en las peticiones de `AVPlayer`, evitando APIs privadas para cabeceras de AVFoundation. Las sesiones se invalidan por TTL y desaparecen al reiniciar el contenedor.

Alternativa descartada: devolver directamente la URL Googlevideo. Puede fallar cuando la URL depende de IP/cabeceras y expone detalles internos al cliente.

### Configuración y autenticación

El VPS leerá `DIEGOMUSIC_API_TOKEN` y `PUBLIC_BASE_URL` desde variables de entorno. El cliente leerá `AUDIO_RESOLVER_BASE_URL` y `AUDIO_RESOLVER_API_TOKEN` desde configuración local generada. El token será una cadena aleatoria de al menos 32 caracteres y se comparará en tiempo constante. La URL pública deberá ser HTTPS salvo en pruebas.

El token incluido en una app privada reduce exposición accidental, pero no se considera secreto frente a alguien que controle el dispositivo. El servicio seguirá aplicando rate limiting en el reverse proxy y podrá rotarlo.

### Reproductor nativo y ciclo de vida

`AudioPlayerCoordinator`, aislado al actor principal, mantendrá un único `AVPlayer`, una tarea de resolución cancelable y un observador periódico de progreso. Seleccionar, avanzar o retroceder cancelará la resolución previa. La finalización avanzará la cola; los errores se mostrarán sin URLs.

En iOS configurará `AVAudioSession` como `.playback`, declarará `UIBackgroundModes/audio` y registrará play, pause, siguiente, anterior y seek en `MPRemoteCommandCenter`. `MPNowPlayingInfoCenter` se actualizará con título, canal, duración, posición y velocidad.

### Migración de interfaz

El dock eliminará `YouTubePlayerView`. La vista compacta mostrará carátula, título y controles; la ampliada añadirá progreso y editor de cola. PrivacyShield y el laboratorio web dejarán de formar parte del entorno y Ajustes mostrará únicamente privacidad local y estado no sensible del resolutor.

## Risks / Trade-offs

- [Cambios de YouTube rompen la resolución] → fijar una versión de `yt-dlp`, reconstruir frecuentemente y disponer de health check y errores clasificables.
- [Una pista no ofrece M4A/AAC] → responder con indisponibilidad clara; añadir transcodificación HLS en un cambio posterior.
- [URLs upstream expiran durante reproducción o seek] → TTL conservador, resolver al iniciar cada pista y permitir reintento explícito.
- [El proxy consume ancho de banda del VPS] → no almacenar audio, soportar rangos y documentar métricas/cuotas del proveedor.
- [Token de stream aparece en access logs] → deshabilitar logs de acceso en la configuración Caddy incluida y usar tokens temporales.
- [AVPlayer realiza varias peticiones concurrentes] → el almacén de sesiones permitirá reutilizar el token hasta expirar y cada petición abrirá su propio stream upstream.
- [Xcode 14 local no valida iOS 17/background] → validar macOS y lógica unitaria ahora; completar dispositivo con Xcode compatible.

## Migration Plan

1. Añadir y probar el servicio resolutor de forma independiente.
2. Añadir configuración cliente y `AudioResolverClient` sin eliminar todavía el reproductor anterior.
3. Sustituir el coordinador y dock por AVPlayer; activar background audio y controles remotos.
4. Retirar recursos IFrame y PrivacyShield del flujo activo.
5. Desplegar el contenedor en un subdominio HTTPS, generar token y configurar el cliente localmente.
6. Probar resolución, rangos, cambio de pista, bloqueo de pantalla y recuperación tras interrupciones.

Rollback: cambiar a `main` o revertir el cambio; esa rama conserva íntegro el reproductor IFrame validado.

## Open Questions

- Evaluar después del MVP si la cobertura real requiere fallback de transcodificación HLS.
- Decidir el proveedor VPS y su política de ancho de banda antes del despliegue de producción.
