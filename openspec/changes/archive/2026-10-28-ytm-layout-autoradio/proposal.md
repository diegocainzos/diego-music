# Cambio: layout estilo YouTube Music, radio automática y cola real

## Why

- La radio solo arranca con un botón, así que al terminar una pista suelta la música se para. El usuario quiere el comportamiento de YouTube Music: el Mix arranca solo.
- La vista de cola de iOS, Android y web pinta las 20 primeras pistas del historial de la cola (`items[0..20]`), no lo que viene después de la actual. En cuanto la cola acumula más de 20 pistas, la radio o «A continuación» nunca se ven cambiar.
- La sección «Para ti» (LLM vía OpenRouter) devuelve canciones irrelevantes; el usuario prefiere eliminarla.
- La interfaz echa de menos el layout de YouTube Music: lista compacta tipo «Selecciones rápidas» (carátula pequeña, título protagonista) y un reproductor con pestañas «A continuación» / «Letras».
- En Safari los títulos de las filas de pista se desbordan en vez de recortarse.

## What Changes

- Reproducir una pista suelta (no un álbum, playlist ni episodio) carga automáticamente el Mix de YouTube detrás de ella en los tres clientes. El botón de radio sigue permitiendo pararla. **Sustituye** el invariante «la radio solo se activa de forma explícita» de `donda-ui-podcasts-radio`.
- La vista de cola muestra la pista actual y las siguientes (hasta 20), y se actualiza en cuanto cambia la cola.
- Inicio gana «Selecciones rápidas»: el Mix de la última pista escuchada en lista compacta (carátula pequeña, título grande, artista secundario) con «Reproducir todo».
- Se elimina «Para ti» en los tres clientes y el endpoint `POST /v1/recommendations` del resolutor (y su uso de OpenRouter).
- El reproductor expandido muestra pestañas «A continuación» y «Letras» bajo los controles.
- Web: los títulos de pista se recortan con «…» dentro de su fila también en WebKit/Safari.
- Tokens Donda intactos: monocromo, radio 0, borde 1 pt, tipografía Donda.

## Capabilities

### New Capabilities

- `playback-and-home`: radio automática, vista de cola, Selecciones rápidas, pestañas del reproductor y truncado de títulos.

### Modified Capabilities

<!-- Sin baseline archivado para radio/inicio. -->

## Impact

- iOS: `AudioPlayerCoordinator.swift`, `PlayerDock.swift`, `HomeView.swift`, `HomeViewModel.swift`, `YouTubeDataService.swift`.
- Android: `PlayerCoordinator.kt`, `PlayerScreen.kt`, `HomeScreen.kt`, `YouTubeDataService.kt`, `YouTubeDtos.kt`.
- Web: `store.ts`, `player.tsx`, `screens.tsx`, `ui.tsx`, `api.ts`, `styles.css`.
- Resolutor: se borran `recommendations.py`, su test, el endpoint, los modelos y la config de OpenRouter.
- `AGENTS.md`: secciones Radio y Recomendaciones.
