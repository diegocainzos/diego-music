## ADDED Requirements

### Requirement: Limpieza avanzada de metadatos de YouTube para letras
DiegoMusic SHALL procesar los metadatos de `MediaItem` (título y canal) eliminando marcas de canal (`- Topic`, `VEVO`, `Official`, etc.), separadores compuestos (` - `, ` — `, ` | `, ` • `) y etiquetas de vídeo no musicales (`(Official Video)`, `(Video Oficial)`, `(Audio)`, `(Remastered ...)`, `[4K]`, `(feat. ...)` tanto en inglés como en español) para extraer un nombre de artista y título limpios.

#### Scenario: Canal con sufijo VEVO o Topic
- **WHEN** un elemento tiene canal `"LadyGagaVEVO"` o `"Coldplay - Topic"`
- **THEN** el extractor normaliza el artista a `"Lady Gaga"` o `"Coldplay"` respectivamente

#### Scenario: Título con etiquetas de producción y vídeo
- **WHEN** un elemento tiene título `"Bohemian Rhapsody (Official Video Remastered)"` o `"Tití Me Preguntó (Video Oficial)"`
- **THEN** el extractor limpia el título a `"Bohemian Rhapsody"` o `"Tití Me Preguntó"`

#### Scenario: Título con separador artista y canción
- **WHEN** el título del vídeo incluye `"Dua Lipa - Levitating (feat. DaBaby) (Official Music Video)"`
- **THEN** el extractor separa el artista `"Dua Lipa"` y la canción `"Levitating"`

### Requirement: Consulta tolerante en cascada a LRCLIB
DiegoMusic SHALL consultar la API de LRCLIB en una cascada de intentos desde el más específico hasta el más tolerante (`/api/get` exacto con y sin duración, `/api/search` estructurado con `artist_name`/`track_name`, y `/api/search` por texto libre `q`), deteniéndose en la primera coincidencia válida.

#### Scenario: Coincidencia exacta con parámetros limpios
- **WHEN** los metadatos limpios coinciden exactamente en LRCLIB
- **THEN** se obtienen las letras en el primer intento sin realizar búsquedas secundarias

#### Scenario: Fallback a búsqueda estructurada y libre
- **WHEN** `/api/get` devuelve 404 debido a diferencias menores en el nombre del artista o título
- **THEN** el proveedor ejecuta `/api/search` estructurado o con consulta libre para localizar candidatos

### Requirement: Puntuación y validación de candidatos de letras
DiegoMusic SHALL puntuar los resultados devueltos por la búsqueda de LRCLIB priorizando letras sincronizadas (`syncedLyrics`), validando la proximidad temporal con `durationSeconds` cuando esté disponible y verificando la correspondencia del artista/tema para evitar letras equivocadas.

#### Scenario: Selección de candidato óptimo con letra sincronizada
- **WHEN** la búsqueda devuelve múltiples versiones (algunas sólo con texto plano y otras sincronizadas)
- **THEN** el proveedor selecciona la versión con letra sincronizada más cercana en duración y nombre

#### Scenario: Descarte de candidatos incompatibles
- **WHEN** los resultados devueltos difieren sustancialmente del artista y título consultados
- **THEN** se descartan los candidatos y se devuelve `.notFound` en lugar de una letra errónea
