# Tasks: Robustez de Streaming VPS y Resolución Automatizada

- [x] 1. Configurar tmpfs para `/home/resolver/.cache` en `ResolverService/compose.yml` <!-- id: 1-compose-tmpfs -->
- [x] 2. Añadir `--extractor-args` en `ResolverService/app/resolver.py` <!-- id: 2-resolver-extractor-args -->
- [x] 3. Ajustar tamaño de chunk a 1MB y método `is_downloading` en `ResolverService/app/audio_cache.py` <!-- id: 3-audiocache-chunks -->
- [x] 4. Actualizar `proxy_audio` y manejo de `HEAD`/espera de descarga en `ResolverService/app/main.py` <!-- id: 4-main-proxy-audio -->
- [x] 5. Actualizar pruebas unitarias en `ResolverService/tests/` <!-- id: 5-unit-tests -->
- [x] 6. Validar con `./scripts/validate-resolver.sh` y reconstruir contenedor Docker <!-- id: 6-validate-and-deploy -->
