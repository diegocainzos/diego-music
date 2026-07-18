## Why

El reproductor IFrame obliga a conservar una superficie de vídeo y pierde continuidad al alternar entre presentaciones SwiftUI. DiegoMusic necesita una experiencia musical nativa, compacta y capaz de continuar en segundo plano en iPhone, manteniendo YouTube como catálogo y fuente del contenido.

## What Changes

- **BREAKING**: sustituir la reproducción mediante YouTube IFrame/WKWebView por audio nativo mediante `AVPlayer`.
- Mantener YouTube Data API, la biblioteca local, favoritos, playlists, historial y cola existentes.
- Añadir un servicio privado desplegable en VPS que resuelva una representación de audio compatible mediante `yt-dlp` y la entregue a través de un proxy opaco con soporte de rangos.
- Autenticar las operaciones de resolución y evitar exponer URLs upstream, cookies, tokens o cabeceras sensibles al cliente y a los logs.
- Añadir reproducción en segundo plano, controles de pantalla bloqueada, eventos de auriculares, progreso y recuperación de errores en iOS.
- Sustituir el reproductor visual por un dock musical compacto con carátula, metadatos, controles y cola ampliable.
- Añadir configuración local para URL y token del resolutor, además de contenedores y documentación de despliegue HTTPS en VPS.
- Retirar PrivacyShield del flujo de reproducción; sus reglas web dejan de aplicarse al no existir un reproductor embebido.

## Capabilities

### New Capabilities

- `private-audio-resolver`: resolución autenticada de pistas YouTube, sesiones opacas y proxy de audio compatible con peticiones HTTP Range.
- `native-audio-playback`: reproducción AVPlayer compacta, cola, progreso, segundo plano y controles del sistema.
- `vps-audio-deployment`: configuración reproducible y segura del resolutor en un VPS mediante contenedores y HTTPS.

### Modified Capabilities

<!-- No hay specs base archivadas que modificar; el cambio reemplaza la implementación IFrame conservada en la rama main. -->

## Impact

- Cliente: `AppEnvironment`, configuración, coordinador de reproducción, dock del reproductor, entitlements, Info.plist y pruebas Swift.
- Servicio nuevo: aplicación Python, `yt-dlp`, `httpx`, FastAPI, Docker y pruebas pytest.
- Operación: dominio HTTPS, token privado, ancho de banda del VPS y actualizaciones periódicas de `yt-dlp`.
- Seguridad: las credenciales permanecen fuera de Git; los IDs se validan y el servicio no acepta URLs arbitrarias.
