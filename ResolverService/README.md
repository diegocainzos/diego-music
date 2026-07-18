# DiegoMusic Private Audio Resolver

Servicio privado que recibe un `videoId`, selecciona una representación M4A/AAC mediante `yt-dlp` y entrega una URL opaca con proxy HTTP Range. No almacena audio permanentemente ni devuelve la URL upstream al cliente.

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

Las sesiones existentes desaparecen al reiniciar; la app resolverá de nuevo la pista.

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
