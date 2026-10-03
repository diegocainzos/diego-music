# Design: Simplificación tras auditoría ponytail

## Contexto

La auditoría ponytail (2026-10-03) clasificó cada hallazgo como `delete`, `stdlib`, `native`, `yagni` o `shrink`. Este cambio los aplica todos, junto con cinco correcciones de seguridad e higiene detectadas durante la lectura. El criterio general es borrar antes que reescribir y no cambiar ningún comportamiento que use un cliente actual.

## Decisiones

### D1. Compose: se conserva el `compose.yml` raíz
`https://music.diegocainzos.cv/` sirve el frontend web (nginx) y `/health`, `/v1` y `/api` sirven el resolver, todo detrás de Traefik y en el mismo host. Solo el `compose.yml` raíz define ambos servicios con esas reglas (`diegomusic-api`, prioridad 100; `diegomusic-web`, prioridad 1), y el README raíz ya documenta `docker compose up -d --build` desde la raíz. Por eso se elimina `ResolverService/compose.yml`. Los volúmenes del proyecto `diegomusic` (`diegomusic_audio_cache`, `diegomusic_db_data`) no cambian. Validación: `docker compose --file compose.yml config --quiet` desde la raíz.

### D2. Caché persistente: solo `yt-dlp`
La ruta `yt-dlp` se introdujo en e79fb2d precisamente porque la copia por rangos con httpx sufría cortes 403. Se elimina la ruta httpx (`_content_length`, `_CONTENT_RANGE`, `_DOWNLOAD_CHUNK_BYTES` y el uso de `anyio`), y `schedule()` y `_download()` dejan de recibir `audio` y `client`. Para conservar los invariantes de AGENTS.md (archivo temporal, validación de tamaño, renombrado atómico y límite por pista), la ruta `yt-dlp` debe:
- escribir con un prefijo temporal oculto, como ya hace;
- descartar la salida si su tamaño es 0 o supera `min(max_file_bytes, max_bytes)`;
- remuxar con `_defragment` y renombrar con `Path.replace` dentro del directorio de caché.

Este cambio sustituye el requisito «Tamaño de fragmento de caché de 1MB» del cambio no archivado `fix-vps-stream-robustness`. Las pruebas usan ejecutables `yt-dlp` y `ffmpeg` falsos (`ResolverService/tests/fake_binaries.py`) y nunca contactan YouTube. Un único helper `_run` ejecuta ambos procesos sin shell, con `stdin` cerrado y timeout, y los mata si expiran o se cancelan (antes `yt-dlp` quedaba vivo tras un timeout). `is_downloading` desaparece porque `schedule()` ya ignora descargas en curso, y el pin explícito de `anyio` sale de `requirements.txt` (sigue llegando como dependencia transitiva).

### D3. Una sola composición FastAPI
`ResolverService/app/main.py:create_app` es la única fábrica. Se elimina `app/main.py`, junto con su CORS `*` que producción nunca usó. `tests/test_backend_auth.py` y `tests/test_playlists_activity.py` se mueven a `ResolverService/tests/`, construyen la app con `create_app(Settings(...))` e importan los módulos del backend como `backend_app.*`. Se eliminan el `requirements.txt` raíz y la carpeta `tests/` raíz. `ResolverService/pytest.ini` usa `pythonpath = . ..` para que el enlace `backend_app` de la raíz se resuelva en local. En Docker, `PYTHONPATH=/service` y `COPY app ./backend_app` ya lo resuelven, así que sobra el `sys.path.insert` de `main.py`. El enlace `app_backend` no tiene uso.

### D4. `SECRET_KEY` obligatoria
`app/config.py` deja de definir un valor por defecto y de usar `os.getenv` dentro de `BaseSettings`. Si `SECRET_KEY` falta o tiene menos de 32 caracteres, la importación lanza un `ConfigurationError` saneado que nombra la variable sin mostrar valores, y no la `ValidationError` cruda de pydantic. `ResolverService/.env.example` añade `SECRET_KEY=` vacío. `compose.yml` ya carga `ResolverService/.env` mediante `env_file`. Las pruebas definen una clave ficticia en `conftest.py` antes de importar.

### D5. Seed demo opcional
`seed_database` solo crea el usuario demo, sin catálogo. `create_app` lo invoca en el arranque solo si `Settings.seed_demo_data` del resolver (leído de `SEED_DEMO_DATA`: `true`, `1` o `yes`) está activo; por defecto, desactivado. Las pruebas llaman a `seed_database` directamente.

### D6. Sin telemetría
Se eliminan `TelemetryLogger.swift`, todas las llamadas a `recordEvent`, el router `telemetry`, el modelo `UserActivityLog` y sus esquemas. El historial de reproducción (`/users/me/history`) sigue cubriendo «qué se escuchó».

### D7. Protocolos Swift
Se conservan `HTTPTransport` (costura de pruebas con cinco dobles), `AudioStreamResolving` (dos implementaciones más dobles) y `YouTubeDataServicing` (implementación real y marcador de posición). Se eliminan los protocolos con una sola implementación y sin dobles: `BackendAPIClientProtocol`, `AuthClientProtocol`, `TokenManaging`, `TelemetryLogging`, `LyricsProviding` y `RelatedTrackProviding`. También se elimina la extensión de valores por defecto de `YouTubeDataServicing` y la de `AudioStreamResolving.invalidate`.

### D8. Accesores solo para pruebas
`cacheEntryCount`, `availableDiskSpaceBytes`, `total_bytes` y `is_cached_file` se eliminan. Las pruebas que los usan pasan a afirmar lo mismo de forma observable, por ejemplo con el número de peticiones del transporte doble o los archivos en el directorio. Si no hay alternativa observable razonable, se conserva el accesor y se documenta en tasks.md.

### D9. Validación Swift en macOS
El entorno de implementación es Linux, sin `xcodebuild` ni `xcodegen`. Las eliminaciones Swift se verifican con búsquedas exhaustivas de referencias. La compilación, las pruebas y la regeneración de `project.pbxproj` quedan como tareas manuales en macOS (sección 7 de tasks.md).

## Riesgos

- **Cliente web**: puede usar endpoints eliminados. Revisarlo antes de desplegar.
- **Arranque**: si `SECRET_KEY` no está en `ResolverService/.env`, el contenedor no arranca. Es el comportamiento buscado (fallo inmediato), pero hay que añadirla antes del despliegue.
- **Swift sin compilar**: hasta ejecutar la sección 7, cualquier referencia omitida solo aparecerá al compilar en macOS.
