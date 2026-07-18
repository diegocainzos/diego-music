# Instrucciones de seguridad de DiegoMusic

- No leas, muestres, resumas, busques ni incluyas en transcripts el contenido de `.env` o `Config/Secrets.xcconfig`.
- Al buscar en el repositorio, excluye explícitamente cualquier `.env`, `Config/Secrets.xcconfig`, `.pi-subagents/`, `.pi/npm/`, `.pi/tools/`, `.venv/` y cualquier `node_modules/`.
- La única comprobación permitida de valores reales es `./scripts/verify-no-secrets.py`, que informa rutas sin imprimir credenciales.
- No registres URLs completas de YouTube Data API porque incluyen el parámetro `key`.
- No copies credenciales, cookies, PO tokens ni URLs multimedia firmadas a código Swift, pruebas, documentación, artefactos OpenSpec, logs ni salidas de agentes.
- En `main`, el reproductor conservado usa YouTube IFrame Player API. En `feature/vps-audio-resolver`, la única resolución multimedia permitida es el servicio privado `ResolverService`; el cliente Swift nunca debe extraer ni recibir la URL upstream.
- El resolutor solo acepta IDs de vídeo validados, no URLs arbitrarias, y nunca debe persistir audio ni registrar tokens de stream.
