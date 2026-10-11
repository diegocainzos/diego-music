# DiegoMusic Private Audio Resolver

Servicio privado que recibe un `videoId`, selecciona una representación M4A/AAC mediante `yt-dlp` y entrega una URL opaca con proxy HTTP Range. Nunca devuelve la URL upstream al cliente y puede conservar M4A en un volumen privado, acotado y configurable.

El mismo proceso sirve la API de usuarios de DiegoMusic (`/api/v1`: autenticación, playlists, favoritos e historial), con código en `app/` de la raíz del repositorio. La imagen lo copia como `backend_app`.

## Requisitos del VPS

- VPS Linux con Docker Engine y Compose v2.
- Dominio o subdominio con registros A/AAAA apuntando al VPS.
- Puertos TCP 80/443 y UDP 443 abiertos.
- Recomendado para uso personal: 1–2 vCPU, 1–2 GB RAM y ancho de banda suficiente para retransmitir audio.

## Configuración inicial

Todos los comandos de Compose se ejecutan desde la raíz del repositorio, donde vive el único `compose.yml` de despliegue (resolver y web detrás de Traefik).

```bash
cp ResolverService/.env.example ResolverService/.env
openssl rand -hex 32   # una vez para DIEGOMUSIC_API_TOKEN y otra para SECRET_KEY
```

Guarda ambos valores en un gestor de contraseñas y escríbelos en `ResolverService/.env`. No los pegues en issues, commits, capturas ni logs. Configura también `RESOLVER_DOMAIN`.

- `DIEGOMUSIC_API_TOKEN`: token estático que usa el cliente nativo en `POST /v1/audio/resolve`.
- `SECRET_KEY`: clave de firma de los JWT de usuario. **Es obligatoria** (mínimo 32 caracteres) y no tiene valor por defecto: sin ella el contenedor no arranca y el error solo nombra la variable. Cambiarla cierra todas las sesiones de usuario.
- `SEED_DEMO_DATA`: déjala en `false` en producción. Con `true`, `1` o `yes` y una base vacía crea el usuario demo; no crea ningún otro dato.

La URL pública se deriva como `https://$RESOLVER_DOMAIN`. Traefik (proxy central del VPS) solicita y renueva automáticamente el certificado TLS y enruta el tráfico hacia el contenedor `resolver`.

## Arranque

```bash
docker compose --file compose.yml config --quiet
docker compose --file compose.yml up --detach --build
curl --fail "https://$RESOLVER_DOMAIN/health"
```

`config --quiet` valida el archivo sin imprimir su contenido: `docker compose config` expande las variables de `ResolverService/.env` y mostraría el token y la clave JWT. Para levantar solo el resolutor, añade `resolver` a `up`; el servicio `web` necesita el repositorio `../diego-music-web`.

Requisito: la red externa `proxy` de Traefik debe existir (`docker network create proxy`) y el contenedor `resolver` se une a ella mediante las etiquetas Traefik definidas en `compose.yml`. El puerto 8080 solo se expone internamente; Traefik es la única entrada pública.

## Cómo funciona la caché

El servicio combina dos capas:

1. **Resolución en memoria:** reutiliza por `videoId` la URL/cabeceras temporales y evita ejecutar `yt-dlp` de nuevo durante hasta tres horas.
2. **M4A persistente:** tras el primer resolve descarga la pista completa en background con `yt-dlp` (sin shell y con timeout) y la remuxa con `ffmpeg` a MP4 progresivo. Escribe en un archivo temporal oculto, descarta resultados vacíos o mayores que `min(AUDIO_CACHE_MAX_FILE_BYTES, AUDIO_CACHE_MAX_BYTES)` y lo publica con un renombrado atómico. Reproducciones posteriores se sirven desde el volumen `audio_cache`, incluso después de reiniciar contenedores.

La primera reproducción no espera la descarga: comienza mediante proxy upstream mientras la caché se calienta. Esto puede duplicar temporalmente el tráfico de esa primera escucha. Las siguientes usan el archivo local y HTTP Range.

Valores predeterminados:

```dotenv
RESOLUTION_CACHE_MAX_ENTRIES=500
RESOLUTION_CACHE_TTL_SECONDS=10800
RESOLUTION_CACHE_SAFETY_MARGIN_SECONDS=300
AUDIO_CACHE_MAX_BYTES=5368709120
AUDIO_CACHE_MAX_FILE_BYTES=268435456
```

El límite global es 5 GiB y el límite por pista 256 MiB. Al superar el global se eliminan primero las pistas menos usadas. Para desactivar almacenamiento persistente sin desactivar la caché de resolución:

```dotenv
AUDIO_CACHE_MAX_BYTES=0
```

En local el volumen vive en Docker Desktop; en un VPS vive en su almacenamiento Docker. `docker compose down` lo conserva y `docker compose down --volumes` lo elimina.

## Configurar DiegoMusic

Añade a `.env` en la raíz del proyecto, además de `YOUTUBE_DATA_KEY`:

```dotenv
AUDIO_RESOLVER_BASE_URL=https://audio.example.com
AUDIO_RESOLVER_API_TOKEN=EL_MISMO_TOKEN_PRIVADO
```

Después ejecuta:

```bash
./scripts/generate-project.sh
```

El token protege `POST /v1/audio/resolve`, `/v1/search`, `/v1/artist/{id}` y `GET /v1/radio/{video_id}` (radio Mix de YouTube, máximo 30 pistas). Las URLs de stream contienen capacidades aleatorias temporales y no deben registrarse.

## Operación

Estado y logs sanitizados:

```bash
docker compose --file compose.yml ps
docker compose --file compose.yml logs --tail 100 resolver
```

Actualizar dependencias fijadas y reconstruir:

```bash
git pull
docker compose --file compose.yml build --pull --no-cache resolver
docker compose --file compose.yml up --detach
```

Para actualizar específicamente `yt-dlp`, cambia su versión en `ResolverService/requirements.txt`, ejecuta las pruebas y reconstruye la imagen.

### Rotar el token

1. Genera otro valor con `openssl rand -hex 32`.
2. Sustituye `DIEGOMUSIC_API_TOKEN` en `ResolverService/.env`.
3. Ejecuta `docker compose --file compose.yml up --detach --force-recreate resolver`.
4. Actualiza `AUDIO_RESOLVER_API_TOKEN` en el `.env` local de DiegoMusic y regenera el proyecto.
5. Reinstala la app en el iPhone.

Las sesiones opacas existentes desaparecen al reiniciar; DiegoMusic invalida el descriptor y reintenta una vez. Los M4A del volumen permanecen disponibles.

### Inspeccionar o limpiar la caché

```bash
docker compose --file compose.yml exec resolver \
  du -sh /var/cache/diegomusic

docker compose --file compose.yml exec resolver \
  sh -c 'rm -f /var/cache/diegomusic/*.m4a /var/cache/diegomusic/.*.part'
```

Tras cambiar límites en `.env`, recrea el servicio:

```bash
docker compose --file compose.yml up --detach --force-recreate resolver
```

## Pruebas locales

Desde la raíz del repositorio:

```bash
./scripts/validate-resolver.sh
```

El script crea `ResolverService/.venv`, instala `requirements-dev.txt` y ejecuta pytest sobre el resolutor y sobre el backend de usuarios (autenticación, playlists, favoritos e historial), siempre mediante `create_app`. `pytest.ini` añade la raíz del repositorio al `pythonpath` para que el enlace `backend_app` resuelva el backend; `tests/conftest.py` fija una `SECRET_KEY` ficticia y una base SQLite temporal.

Las pruebas sustituyen `yt-dlp`, `ffmpeg` y Googlevideo por ejecutables y dobles locales; no contactan YouTube ni muestran URLs firmadas.

## Seguridad operativa

- No conviertas este servicio en un proxy público.
- Mantén Docker, Traefik y `yt-dlp` actualizados.
- Aplica límites de tráfico en el firewall o proveedor del VPS.
- No habilites access logs sin redactar `/v1/audio/stream/*`.
- Si necesitas cookies, móntalas como secreto de solo lectura y nunca dentro de la imagen o repositorio.
- No expongas directamente el puerto interno 8080; Traefik es la única entrada.
- No imprimas ni registres `SECRET_KEY`, `DIEGOMUSIC_API_TOKEN` ni `ResolverService/.env`; valida Compose siempre con `config --quiet`.
- Protege el volumen `audio_cache`; contiene archivos M4A completos y no debe publicarse ni montarse en otros servicios.
