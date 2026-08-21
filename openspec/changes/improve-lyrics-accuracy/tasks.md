## 1. Limpieza de Metadatos (TrackMetadataExtractor)

- [x] 1.1 Implementar normalización de canales de YouTube (remover `- Topic`, `VEVO`, `Official`, `Music`, etc.)
- [x] 1.2 Implementar detección y división de separadores artista-título (` - `, ` — `, ` | `, ` • `, ` // `)
- [x] 1.3 Implementar eliminación exhaustiva de etiquetas audiovisuales y de producción en inglés y español (`(Official Video)`, `(Video Oficial)`, `(Audio Oficial)`, `[Videoclip]`, `(Remastered ...)`, `[4K]`, `(feat. ...)`)
- [x] 1.4 Añadir pruebas unitarias exhaustivas para `TrackMetadataExtractor` con casos reales de YouTube

## 2. Pipeline de Consulta en Cascada a LRCLIB (LRCLibLyricsProvider)

- [x] 2.1 Añadir soporte para consulta `/api/get` con parámetro `duration` cuando `durationSeconds` esté disponible
- [x] 2.2 Implementar `/api/search` estructurado enviando `artist_name` y `track_name` separados
- [x] 2.3 Implementar fallback a búsqueda libre `/api/search?q=...` y búsqueda sólo por título si el canal es genérico
- [x] 2.4 Implementar sistema de scoring y filtrado de candidatos de búsqueda (prioridad de synced lyrics, tolerancia de duración y verificación de artista)

## 3. Validación y Pruebas

- [x] 3.1 Ejecutar suite de pruebas unitarias de Swift para verificar que todos los casos pasan
- [x] 3.2 Verificar que `./scripts/verify-no-secrets.py` pasa limpiamente sin secretos
