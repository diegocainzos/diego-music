# Diseño (contrato CONGELADO)

## Radio automática

| Cliente | Pista suelta (radio) | Lista (sin radio) |
|---|---|---|
| iOS | `AppEnvironment.play(_:)` → `player.select(item, autoRadio: true)` | `playQueue` → `player.select(current)` (default `autoRadio: false`) |
| Android | `DiegoMusicApp.play(item)` → `player.select(item, autoRadio = true)` | `playQueue` → `player.select(it)` (default `false`) |
| Web | `player.play(t)` | `player.playQueue(items, i)` |

- `select(..., autoRadio: true)` hace lo mismo que hoy y después llama a `startRadio(silent: true)`.
- `startRadio(silent:)` (Swift `startRadio(silent: Bool = false)`, Kotlin `startRadio(silent: Boolean = false)`, web `startRadio(silent = false)`): con `silent` un fallo o lista vacía **no** pone `errorMessage`/toast; la cola y `radioSeedTitle` quedan intactos.
- Obsolescencia: iOS/Android cancelan `radioTask`/`radioJob` en cada `select`; web descarta si la pista actual ya no es la semilla (comprobación existente) — y además si el id de la semilla coincide pero `playback.items` cambió de identidad desde la petición (usar un contador `radioGeneration`).
- `stopRadio()` sin cambios (restaura `savedUpcoming`).
- Estado expuesto sin cambios: `radioSeedTitle` (Swift/Kotlin), `radioSeed` (web).

## Ventana de cola

Función pura, mismo nombre en los tres clientes:
- Swift: `PlaybackQueue.upNextWindow(limit: Int = 20) -> [(index: Int, item: MediaItem)]`
- Kotlin: `QueueState.upNextWindow(limit: Int = 20): List<IndexedValue<MediaItem>>`
- Web (`web/src/queue.ts`, sin DOM; `store.ts` la re-exporta): `upNextWindow(items: Track[], index: number | null, limit = 20): { index: number; track: Track }[]`

Devuelve la actual (si existe) y hasta `limit` posteriores, en orden de cola, con su índice absoluto. `index` nulo → vacío. La vista usa el índice absoluto en `selectFromQueue`.

## Selecciones rápidas

- Fuente: `radio(seed)` ya existente (`/v1/radio/{id}`) con la pista más reciente del historial; se excluye la semilla; máx. 20.
- Swift: `HomeViewModel.quickPicks: [MediaItem]` + `loadQuickPicks(seed: MediaItem?) async`. Kotlin: estado local en `HomeScreen` con `app.youtube.radio(id)`. Web: estado local en `Home` con `api.radio(id)`.
- Fallo/vacío/sin historial → sección oculta, sin error.
- Layout: rejilla horizontal de 4 filas por columna (web: CSS grid `grid-auto-flow: column; grid-template-rows: repeat(4, auto)`, scroll-x; Android `LazyHorizontalGrid(rows = 4)`; iOS `ScrollView(.horizontal) { LazyHGrid(rows: 4) }`). Columna ≈ 85% del ancho en móvil, máx. 360 pt/px.
- Fila: carátula 48 (cuadrada, hairline), título en fuente de cuerpo 15–16 semibold 1 línea, artista con `.dondaLabel` 1 línea. Tap → reproducción de pista suelta.
- Cabecera: título de sección «SELECCIONES RÁPIDAS» + botón outline «REPRODUCIR TODO» → `playQueue(quickPicks, 0)`.
- Se coloca la primera sección de Inicio (después de «Continuar» en iOS).

## Recomendaciones LLM (eliminado)

- Resolutor: borrar `app/recommendations.py`, `tests/test_recommendations.py`, el endpoint `POST /v1/recommendations`, `first_match`/`search_slots` si quedan sin uso, `RecommendationSeed`/`RecommendationsRequest` en `models.py`, `openrouter_*` en `config.py`, y las líneas OpenRouter de `.env.example`.
- Clientes: borrar `recommendations(...)` y su caché en los servicios, la sección «Para ti» y sus DTOs.
- `AGENTS.md`: sustituir la viñeta «Recomendaciones» por «Selecciones rápidas» y la de «Radio» por la radio automática.

## Pestañas del reproductor (solo música)

- Bajo los controles de transporte (y el botón de radio), barra de dos pestañas a todo el ancho: `A CONTINUACIÓN` | `LETRAS`, borde 1 pt `outline`; la seleccionada invertida (fondo `textPrimary`, texto `background`). Por defecto `A CONTINUACIÓN`.
- `A CONTINUACIÓN` → vista de cola (ventana de arriba). `LETRAS` → la vista de letras existente incrustada en un contenedor de alto fijo (≈ 60% del alto de pantalla) dentro del reproductor; el botón de letras de la cabecera selecciona esta pestaña en lugar de abrir otra hoja.
- Episodios: sin pestañas.

## Web: truncado en WebKit

- Los `<button>` que actúan como filas flex (`button.row`, `button.col`) llevan `min-width: 0` y los hijos `.col.grow` también, para que Safari permita encoger y aplicar `.ellipsis`/`.clamp2`. Verificación con WebKit de Playwright a 375 px.

## Errores

Sin códigos nuevos. `POST /v1/recommendations` pasa a 404/405 (ruta inexistente).
