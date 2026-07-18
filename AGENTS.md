# Instrucciones de seguridad de DiegoMusic

- No leas, muestres, resumas, busques ni incluyas en transcripts el contenido de `.env` o `Config/Secrets.xcconfig`.
- Al buscar en el repositorio, excluye explícitamente `.env`, `Config/Secrets.xcconfig`, `.pi-subagents/`, `.pi/npm/` y cualquier `node_modules/`.
- La única comprobación permitida del valor real es `./scripts/verify-no-secrets.py`, que informa rutas sin imprimir la clave.
- No registres URLs completas de YouTube Data API porque incluyen el parámetro `key`.
- No copies credenciales a código Swift, pruebas, documentación, artefactos OpenSpec ni salidas de agentes.
- El reproductor debe seguir usando YouTube IFrame Player API; no extraigas URLs multimedia.
