# Diseño: web Donda unificada

## Decisions

### 1. Misma fuente de verdad visual
Los tokens de `DesignSystem.swift` se copian como variables CSS (`--bg`, `--text`, `--text2`, `--hairline`, `--outline`) con las variantes negro y blanco. Tipografía: `ui-monospace` para etiquetas y una familia condensada del sistema para títulos. Sin Tailwind ni librerías de componentes: los estilos Donda caben en una hoja de CSS.

### 2. Autenticación y datos
- El JWT se guarda en `localStorage` y se envía como `Bearer` a `/api/v1` y `/v1`. El resolutor ya acepta el JWT de usuario además del token estático, así que el navegador nunca ve secretos.
- La biblioteca vive en el backend: favoritos, playlists e historial se leen y escriben directamente, sin copia local.
- Mismo origen: Traefik enruta `/v1`, `/api` y `/health` al resolutor y el resto a la web. En desarrollo, Vite hace de proxy.

### 3. Reproducción
Un único `<audio>` gestionado por un store propio: cola, aleatorio, repetir, radio explícita (`/v1/radio`), precarga del siguiente descriptor y un reintento tras error. Media Session API para los controles del sistema en móvil.

### 4. Catálogo
Búsqueda y artistas usan `/v1/search` y `/v1/artist/{id}` (yt-dlp en el VPS). *Alternativa descartada*: YouTube Data API desde el navegador, porque expondría la clave.

### 5. APK
`scripts/publish-apk.sh` ejecuta `./gradlew :app:assembleRelease`, copia el APK a `web/downloads/diegomusic.apk` e imprime el SHA‑1 del certificado para restringir la clave de YouTube en Google Cloud. Nginx sirve `/downloads/` con `Content-Type: application/vnd.android.package-archive`.

## Risks / Trade-offs

- **El APK incluye la clave de YouTube Data API.** Hay que restringirla en Google Cloud a `com.diegocainzos.diegomusic` y al SHA‑1 que imprime el script (la app envía `X-Android-Package` y `X-Android-Cert`). El token estático del resolutor ya no va en el APK.
- **Sin podcasts en la web** por la misma razón.
