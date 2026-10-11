# Cambio: cliente Android nativo con la interfaz Donda

## Why

DiegoMusic solo funciona en iPhone, iPad y Mac. El usuario quiere usarlo en Android, y la versión Android que circulaba no funciona bien y tiene una interfaz que no sigue el sistema Donda. El README menciona `diego-music-android/`, pero ese directorio no existe en el repositorio.

## What Changes

- Nueva app Android nativa en `android/` (Kotlin, Jetpack Compose, Media3), con paridad funcional con la app Swift:
  - autenticación obligatoria contra el backend (`/api/v1/auth/*`) y sincronización de favoritos, playlists e historial;
  - catálogo idéntico al de Swift: YouTube Data API v3 con `KeyPool` y caída al VPS (`/v1/search`, `/v1/artist/{id}`) cuando se agota la cuota;
  - reproducción con un único reproductor Media3 coordinado por `PlayerCoordinator`, sesiones opacas del resolutor (`POST /v1/audio/resolve`), precarga silenciosa, un reintento automático, segundo plano, notificación multimedia y pantalla de bloqueo;
  - radio explícita (`GET /v1/radio/{video_id}`), recomendaciones «PARA TI» (`POST /v1/recommendations`) y calentamiento (`warm`);
  - podcasts (programas seguidos, solo episodios ≥ 40 min, progreso por episodio, velocidad 1×–2×, −15 s / +30 s, descarga);
  - descargas offline, letras LRCLIB con la cascada de 5 niveles y banner sin conexión.
- Interfaz Donda copiada 1:1: mismos tokens, temas negro y blanco, tipografía monoespaciada y condensada en mayúsculas, radio 0, bordes de 1 dp, tres pestañas, mini‑player flotante y reproductor expandido.
- Corrección respecto a Swift: la búsqueda pide también canales (`type=channel`), así que «SEGUIR» y el ámbito «Artistas» de Buscar funcionan de verdad.
- Las credenciales se leen del `.env` raíz al compilar (`BuildConfig`) y nunca se versionan. A diferencia de iOS, el APK no lleva el token estático del resolutor: usa el JWT del usuario, porque el APK se descarga desde la web.

## Capabilities

### New Capabilities

- `android-client`: app Android con paridad funcional y visual con el cliente Swift.

### Modified Capabilities

- Ninguna. El backend y el resolutor no cambian.

## Non-goals

- Android Auto (equivalente a CarPlay), widgets, tablets con barra lateral y Wear OS.
- Descargas que sobrevivan al cierre del proceso (WorkManager). Igual que en Swift, la cola vive mientras la app está abierta.
- Publicación en Google Play y firma de release.
- Cambios en el backend, el resolutor o la app Swift.

## Impact

- Nuevo directorio `android/` con un único módulo `app`.
- `.gitignore`: `android/.gradle/`, `android/local.properties`, `android/.kotlin/`.
- `scripts/verify-no-secrets.py`: excluye `.gradle` (caché local de Gradle, no versionable).
- `README.md` y `AGENTS.md`: ruta real del cliente Android y su validación.
