## 1. Cliente
- [x] 1.1 Botón favorito en el reproductor expandido
- [x] 1.2 `podcastEpisodes(channelID:pageToken:)` + «CARGAR MÁS EPISODIOS»
- [x] 1.3 Sección «PARA TI» en Inicio con `recommendations(basedOn:)`

## 2. Resolutor
- [x] 2.1 `POST /v1/recommendations` (OpenRouter + `ytsearch1`, 503 sin clave, 502 sanitizado)
- [x] 2.2 Pruebas con transporte simulado

## 3. Despliegue
- [ ] 3.1 Añadir `OPENROUTER_API_KEY` en `ResolverService/.env` del VPS y reconstruir
