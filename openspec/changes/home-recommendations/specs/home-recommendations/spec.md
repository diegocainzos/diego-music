## ADDED Requirements

### Requirement: Favorito desde el reproductor
El reproductor expandido SHALL mostrar, para música, un botón que alterna la canción actual en favoritos y refleja su estado al instante.

#### Scenario: Marcar favorito
- **WHEN** el usuario pulsa el corazón con una canción sonando
- **THEN** la canción aparece en Biblioteca → Canciones y el icono pasa a relleno

### Requirement: Más episodios bajo demanda
El detalle de podcast SHALL ofrecer cargar episodios más antiguos mientras la playlist de uploads tenga más páginas, sin `search.list`.

#### Scenario: Cargar más
- **WHEN** la página actual devolvió `nextPageToken` y el usuario pulsa «CARGAR MÁS EPISODIOS»
- **THEN** se piden las siguientes páginas desde ese cursor y se añaden los episodios ≥ 40 min sin duplicados

### Requirement: Recomendaciones por LLM
El resolutor SHALL exponer `POST /v1/recommendations`, autenticado, que acepta de 1 a 20 pistas (título y canal, máximo 200 caracteres cada uno) y devuelve vídeos recomendados. La clave de OpenRouter SHALL vivir solo en el servidor.

#### Scenario: Sin clave configurada
- **WHEN** `OPENROUTER_API_KEY` está vacía
- **THEN** responde 503 y Inicio no muestra la sección

#### Scenario: Fallo del LLM
- **WHEN** OpenRouter falla o devuelve algo que no es JSON válido
- **THEN** responde 502 con «Recomendaciones no disponibles.» sin detalles internos

#### Scenario: Recomendaciones válidas
- **WHEN** el LLM devuelve canciones
- **THEN** cada una se busca con `ytsearch1` (como máximo 2 a la vez) y se devuelven vídeos únicos
