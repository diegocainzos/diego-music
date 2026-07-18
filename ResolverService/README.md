# DiegoMusic Private Audio Resolver

Servicio privado que recibe un `videoId`, selecciona una representación M4A/AAC mediante `yt-dlp` y entrega una URL opaca con proxy HTTP Range. Nunca devuelve la URL upstream al cliente y puede conservar M4A en un volumen privado, acotado y configurable.

## Requisitos del VPS

- VPS Linux con Docker Engine y Compose v2.
- Dominio o subdominio con registros A/AAAA apuntando al VPS.
- Puertos TCP 80/443 y UDP 443 abiertos.
- Recomendado para uso personal: 1–2 vCPU, 1–2 GB RAM y ancho de banda suficiente para retransmitir audio.

## Configuración inicial

```bash
cd ResolverService
cp .env.example .env
TOKEN="$(openssl rand -hex 32)"
printf '%s\n' "$TOKEN"
```

Guarda el token en un gestor de contraseñas y escribe el mismo valor como `DIEGOMUSIC_API_TOKEN` en `ResolverService/.env`. No lo pegues en issues, commits, capturas ni logs. Configura también `RESOLVER_DOMAIN`.

La URL pública se deriva como `https://$RESOLVER_DOMAIN`. Caddy solicita y renueva automáticamente el certificado TLS.

## Arranque

```bash
docker compose --file compose.yml config
docker compose --file compose.yml up --detach --build
curl --fail "https://$RESOLVER_DOMAIN/health"
```

El puerto 8080 solo se expone dentro de la red Compose. Caddy no habilita access logs por defecto para evitar registrar tokens temporales incluidos en rutas de stream.

## Cómo funciona la caché

El servicio combina dos capas:

1. **Resolución en memoria:** reutiliza por `videoId` la URL/cabeceras temporales y evita ejecutar `yt-dlp` de nuevo durante hasta tres horas.
2. **M4A persistente:** tras el primer resolve descarga la pista completa en background. Reproducciones posteriores se sirven desde el volumen `audio_cache`, incluso después de reiniciar contenedores.

La primera reproducción no espera la descarga: comienza mediante proxy upstream mientras la caché se calienta. Esto puede duplicar temporalmente el tráfico de esa primera escucha. Las siguientes usan el archivo local y HTTP Range.

Valores predeterminados:

```dotenv
RESOLUTION_CACHE_MAX_ENTRIES=500
RESOLUTION_CACHE_TTL_SECONDS=10800
RESOLUTION_CACHE_SAFETY_MARGIN_SECONDS=300
AUDIO_CACHE_MAX_BYTES=5368709120
AUDIO_CACHE_MAX_FILE_BYTES=268435456
```

El límite global es 5 GiB. Al superarlo se eliminan primero las pistas menos usadas. Para desactivar almacenamiento persistente sin desactivar la caché de resolución:

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

El token se usa únicamente en `POST /v1/audio/resolve`. Las URLs de stream contienen capacidades aleatorias temporales y no deben registrarse.

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

Para actualizar específicamente `yt-dlp`, cambia su versión en `requirements.txt`, ejecuta las pruebas y reconstruye la imagen.

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

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/pytest -q
```

Las pruebas sustituyen `yt-dlp` y Googlevideo por dobles locales; no contactan YouTube ni muestran URLs firmadas.

## Seguridad operativa

- No conviertas este servicio en un proxy público.
- Mantén Docker, Caddy y `yt-dlp` actualizados.
- Aplica límites de tráfico en el firewall o proveedor del VPS.
- No habilites access logs sin redactar `/v1/audio/stream/*`.
- Si necesitas cookies, móntalas como secreto de solo lectura y nunca dentro de la imagen o repositorio.
- No expongas directamente el puerto interno 8080.
- Protege el volumen `audio_cache`; contiene archivos M4A completos y no debe publicarse ni montarse en otros servicios.
