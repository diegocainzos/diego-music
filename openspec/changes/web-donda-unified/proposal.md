# Cambio: web Donda unificada con descarga del APK

## Why

La web de DiegoMusic (`../diego-music-web`) solo existe en el VPS, fuera del repositorio, y no sigue el sistema Donda que ya comparten iOS, macOS y Android. El usuario quiere la misma temática y estructura en todas las apps y un botón para descargar el APK de Android desde la web.

## What Changes

- Nueva web en `web/` (React 19, TypeScript y Vite, sin dependencias de UI) con la interfaz Donda: mismos tokens, temas negro y blanco, tipografía monoespaciada y condensada en mayúsculas, radio 0 y bordes de 1 px.
- Misma estructura que las apps: puerta de autenticación, tres secciones (Inicio, Buscar, Biblioteca; barra inferior en móvil y lateral en escritorio), mini‑player flotante, reproductor expandido con cola, radio explícita y letras LRCLIB, y Ajustes.
- Toda la web usa el JWT del usuario: `/api/v1` para cuenta, favoritos, playlists e historial, y `/v1/*` para resolver audio, buscar, artistas, radio y recomendaciones. No hay claves ni tokens en el navegador.
- Botón «DESCARGAR APK» en la puerta de entrada, en Inicio y en Ajustes, que apunta a `/downloads/diegomusic.apk`.
- `scripts/publish-apk.sh` compila el APK y lo deja en `web/downloads/` (ignorado por git); `compose.yml` construye la web desde `./web` y monta esa carpeta en solo lectura.

## Capabilities

### New Capabilities

- `web-client`: cliente web Donda unificado con descarga del APK.

## Non-goals

- Podcasts y descargas offline en la web: necesitan la clave de YouTube Data API o almacenamiento local, y la web no debe llevar claves.
- Cambios en el backend o el resolutor.

## Impact

- Nuevo `web/` con su `Dockerfile` y `nginx.conf`.
- `compose.yml`: el servicio `web` pasa de `../diego-music-web` a `./web` y monta `./web/downloads`.
- `.gitignore`, `README.md` y `AGENTS.md`.
