# AGENTS.md — DiegoMusic

Estas instrucciones se aplican a todo el repositorio. Cualquier agente automatizado debe leerlas antes de buscar, editar, ejecutar pruebas o desplegar servicios.

## Objetivo del proyecto

DiegoMusic es un cliente privado para iOS/iPadOS 17+ y macOS 14.8.5+. Usa YouTube Data API v3 para catálogo y metadatos, y un resolutor FastAPI privado para entregar audio a un único `AVPlayer` mediante sesiones opacas.

La arquitectura nativa VPS + AVPlayer vive actualmente en `main`. No reintroducir WebKit, YouTube IFrame Player, PrivacyShield ni extracción multimedia en Swift salvo petición explícita y un cambio OpenSpec aprobado.

## Reglas críticas de seguridad

1. **Nunca leer, mostrar, resumir, buscar ni incluir en transcripts valores de:**
   - `/.env`;
   - `/ResolverService/.env`;
   - `/Config/Secrets.xcconfig`;
   - cookies, PO tokens, Bearer tokens o credenciales equivalentes.
2. Los archivos `.env.example` y `Secrets.xcconfig.example` sí pueden leerse porque solo contienen placeholders.
3. Al hacer búsquedas globales, excluir siempre:
   - `.env` y cualquier variante local no terminada en `.example`;
   - `Config/Secrets.xcconfig`;
   - `.pi-subagents/`, `.pi/npm/`, `.pi/tools/`;
   - `.venv/`, `node_modules/`, datos Docker y artefactos de build.
4. La única comprobación permitida sobre valores reales es `./scripts/verify-no-secrets.py`; informa rutas sin imprimir secretos.
5. No ejecutar `docker compose config` mostrando stdout: puede expandir el token. Usar `docker compose config --quiet`.
6. No registrar ni devolver:
   - URLs completas de YouTube Data API, porque incluyen `key`;
   - URLs upstream de Googlevideo;
   - cabeceras upstream;
   - tokens opacos de `/v1/audio/stream/*`;
   - rutas internas de archivos cacheados.
7. Los mensajes de error para el cliente deben estar sanitizados y nunca incorporar excepciones crudas de `yt-dlp`, HTTP o filesystem.
8. No habilitar access logs de Traefik sin redactar las rutas de stream.

Si un secreto aparece accidentalmente en una salida o artefacto, detener el trabajo, eliminar el artefacto, rotar la credencial afectada y documentar el incidente sin repetir el valor.

## Invariantes de arquitectura

### Cliente Swift

- El cliente solo envía un `videoId` validado al resolutor.
- El cliente nunca debe extraer audio, ejecutar `yt-dlp`, recibir URLs upstream ni construir URLs arbitrarias.
- Debe existir un único `AVPlayer` coordinado por `AudioPlayerCoordinator`.
- Mantener reproducción en segundo plano, Now Playing y `MPRemoteCommandCenter`.
- Estado observable y operaciones de UI deben respetar `@MainActor`; caché y deduplicación de red pertenecen al actor `AudioResolverClient`.
- Una sesión inválida puede provocar como máximo un reintento automático antes de mostrar un error sanitizado.
- La precarga de la siguiente pista debe ser silenciosa y no cambiar la pista actual.

### ResolverService

- Aceptar exclusivamente IDs de vídeo que satisfagan la validación vigente; nunca URLs aportadas por el usuario.
- `yt-dlp` debe ejecutarse sin shell, con argumentos controlados y timeout.
- La URL y cabeceras upstream solo viven dentro del servicio.
- Las respuestas públicas contienen únicamente una capacidad opaca y metadatos no sensibles.
- Conservar semántica correcta para `GET`, `HEAD`, HTTP Range, `206` y `416`.
- FastAPI no debe publicar directamente el puerto 8080; Traefik es la única entrada pública.
- Mantener `read_only`, `no-new-privileges`, tmpfs limitado y HTTPS.

### Cachés

- La caché de búsqueda (`SearchCache`) es un actor Swift en memoria con TTL de 24h y normalización de texto para deduplicar búsquedas.
- La caché de resolución es temporal, LRU, limitada y nunca puede superar la expiración upstream menos su margen de seguridad.
- La caché de artistas en el servidor (`ArtistCache`) mantiene perfiles y éxitos en memoria LRU en FastAPI (`ARTIST_CACHE_MAX_ENTRIES=1000`, `ARTIST_CACHE_TTL_SECONDS=86400`).
- Las solicitudes simultáneas para un mismo `videoId` deben usar single-flight.
- La caché M4A persistente solo puede escribir en el volumen `audio_cache`.
- Las descargas deben usar archivos temporales, validación de tamaño y renombrado atómico.
- Nunca servir un archivo parcial.
- Aplicar límite global, límite por pista y expulsión LRU.
- Un token emitido antes de terminar el calentamiento debe poder cambiar a disco sin revelar la ruta ni exigir otro resolve.
- Los fallos de calentamiento son best-effort: no deben interrumpir la reproducción upstream existente.

### Sistema de Letras (Lyrics & LRCLIB)

- **Normalización de metadatos de YouTube:** LRCLIB es una base de datos comunitaria estricta. El texto crudo de YouTube (canales con `- Topic`, `VEVO`, `Official`, `Music` o títulos con `(Official Video)`, `(Video Oficial)`, `(Audio)`, `(Remastered ...)`, `[4K]`, `(feat. ...)`) devuelve 0 resultados en búsquedas de texto completo.
  - Limpiar canales y títulos antes de consultar LRCLIB.
  - Separar nombres CamelCase en canales VEVO (`LadyGagaVEVO` → `Lady Gaga`).
  - Dividir artista y canción usando separadores universales (` - `, ` — `, ` – `, ` | `, ` • `, ` // `).
- **Cascada tolerante de consulta (5 niveles):**
  1. `/api/get` con `artist_name`, `track_name` y `duration` (`durationSeconds`).
  2. `/api/get` exacto sin duración.
  3. `/api/search` estructurado enviando `artist_name` y `track_name` por separado.
  4. `/api/search` libre con `q = "\(artist) \(track)"`.
  5. Fallback por `track_name` únicamente si el título fue limpiado.
  - Validar candidatos puntuando letras sincronizadas (`syncedLyrics` > `plainLyrics`) y verificando tolerancia de duración (±3 a 8s; descartar >60s) para evitar letras erróneas.
- **Invariante de Layout en SwiftUI (`LyricsView`):**
  - Dentro de `ScrollView`, `LazyVStack` **DEBE** tener su anchura estrictamente fijada a la ventana visible (`.frame(width: viewportWidth, alignment: .leading)`).
  - Si no se fija la anchura horizontal, los textos largos expanden el ancho intrínseco del contenedor, provocando que `ScrollView` centre el contenido y desplace el inicio de las frases fuera de la pantalla por la izquierda en orientación vertical.

## Fuente de verdad del proyecto Xcode

- `project.yml` es la fuente de verdad.
- Modificar `project.yml` y regenerar con `./scripts/generate-project.sh`; evitar editar `DiegoMusic.xcodeproj/project.pbxproj` manualmente.
- Preservar:
  - bundle ID `com.diegocainzos.DiegoMusic`;
  - iOS/iPadOS 17 y macOS 14.8.5;
  - firma automática y Team existentes, salvo petición explícita;
  - `UIBackgroundModes = audio`;
  - entitlements vigentes.
- Core Data es deliberado; no migrar a SwiftData salvo petición explícita.

## Flujo de trabajo

1. Leer `README.md`, este archivo y la documentación específica del componente.
2. Para cambios de comportamiento o arquitectura, crear o actualizar un cambio bajo `openspec/changes/` antes de implementar.
3. Mantener propuesta, diseño, especificaciones y tareas sincronizados con el código real.
4. Realizar cambios pequeños, tipados y probables; no introducir dependencias sin necesidad.
5. Regenerar el proyecto si cambian fuentes, recursos, settings o targets.
6. Ejecutar las validaciones relevantes.
7. Revisar `git diff --check` y `git status` antes de declarar el trabajo terminado.
8. No hacer commit, merge, push, rebase ni eliminar ramas salvo petición del usuario.
9. Existe remoto `origin` (github.com/diegocainzos/diego-music); nunca asumir que un commit fue publicado sin verificar.

## Validación obligatoria

Para cambios generales:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/validate.sh
```

Para cambios únicamente en el resolutor:

```bash
./scripts/verify-no-secrets.py
./scripts/validate-resolver.sh
cd ResolverService
docker compose --file compose.yml config --quiet
```

Para cambios Swift, ejecutar como mínimo:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Para cambios OpenSpec:

```bash
.pi/openspec/node_modules/.bin/openspec validate <change-id> --type change --strict
```

Las capacidades de pantalla bloqueada, auriculares, interrupciones y controles remotos deben verificarse en un iPhone físico con una versión compatible de Xcode.

## Convenciones de implementación

- Swift: tipos pequeños, errores explícitos, dependencias inyectables y aislamiento de concurrencia correcto.
- Python: type hints, I/O asíncrono, límites explícitos y excepciones públicas sanitizadas.
- Pruebas: no contactar YouTube ni Googlevideo; usar dobles locales y datos ficticios.
- No añadir analytics, tracking, telemetría o logs sensibles.
- No sustituir Core Data, AVPlayer, FastAPI, Traefik o `yt-dlp` sin justificarlo en OpenSpec.
- Mantener la interfaz experimental, tranquila y lúdica dentro del sistema Bauhaus Hi‑Fi existente.

## Operación Docker

- No leer `ResolverService/.env` para diagnosticar; comprobar presencia, estado y healthcheck sin imprimir contenido.
- No usar `docker inspect` de forma que exponga variables de entorno.
- `docker compose down` conserva volúmenes; `down --volumes` es destructivo y requiere autorización explícita.
- No eliminar ni vaciar `audio_cache` sin confirmación del usuario.
- Actualizar `yt-dlp` reconstruyendo la imagen; no instalar paquetes manualmente dentro del contenedor en ejecución.

## Herramientas Pi

- Las herramientas compartidas de Pi se gestionan desde `~/pi-setup`.
- Antes de modificar paquetes, extensiones, skills, prompts, temas, browser tooling o sincronización Pi, leer `~/pi-setup/WORKFLOW.md`.
- No instalar capacidades compartidas en `~/.pi/agent`, `~/.agents` ni mediante `pi install` global salvo petición explícita.
- Las herramientas específicas de DiegoMusic permanecen bajo `./.pi` y no deben añadirse a `~/pi-setup/package.json`.
- Usar Context7 cuando se necesite documentación de librerías o APIs.

## Documentación relacionada

- [`README.md`](README.md): instalación, arquitectura y operación.
- [`YOUTUBE_MUSIC_CLIENT_SPEC.md`](YOUTUBE_MUSIC_CLIENT_SPEC.md): especificación funcional original.
- [`ResolverService/README.md`](ResolverService/README.md): despliegue y mantenimiento del VPS.
- [`openspec/changes/`](openspec/changes/): decisiones y requisitos implementados.
