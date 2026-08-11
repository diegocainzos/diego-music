# Design — Rediseño Integral Apple Music Web

## Context

El usuario requiere transformar la interfaz de DiegoMusic para clonar fielmente la experiencia visual y interactiva de Apple Music Web. Tras capturar y analizar las capturas de referencia (`browse.png`, `radio.png`, `library.png`, `album_detail.png`, `player.png`), identificamos la necesidad de adaptar el sistema de tokens de diseño, incorporar navegación por historial (`<` y `>`), estructurar la barra lateral para iPad/macOS y adaptar el dock de reproducción superior/inferior estilo glassmorphism con control de volumen, scrubber y accesos directos.

## Goals / Non-Goals

**Goals**:
- Adoptar el color de acento carmesí de Apple Music (`#FA233C`) y los materiales traslúcidos glassmorphism (`.ultraThinMaterial` / `.regularMaterial`).
- Implementar un gestor de pila de navegación `NavigationHistoryStore` con métodos `goBack()` y `goForward()` habilitados/deshabilitados según el estado del stack.
- Rediseñar el `PlayerDock` para alinearlo visual y funcionalmente al reproductor superior/flotante de Apple Music Web (arte, título, artista, scrubber interactivo, volumen, letras y cola).
- Conservar la adaptabilidad responsive (`TabView` en iPhone compacto, Sidebar + Header en iPad/macOS).

**Non-Goals**:
- No reestructurar la lógica interna del resolutor VPS ni de `yt-dlp`.
- No alterar la firma de `AudioPlayerCoordinator` ni romper el actor `LibraryStore`.

## Decisions

### D1. Tokens de diseño unificados en `DiegoTheme`
Se actualizan las constantes de color en `DiegoTheme`:
- `accent`: Color(red: 0.98, green: 0.14, blue: 0.24) (`#FA233C`).
- `background`: Fondo oscuro profundo `#111112` con soporte para adaptación de esquema claro/oscuro.
- `surface` y `glass`: `.ultraThinMaterial` / `.regularMaterial` con trazo fino de borde (`Color.white.opacity(0.08)`).

### D2. Gestor de pila de navegación (`NavigationHistoryStore`)
Un `@StateObject` o `@EnvironmentObject` mantendrá la pila de destinos visitados (`backStack` y `forwardStack`). Permite a la cabecera renderizar botones `<` y `>` habilitados dinámicamente al navegar entre Inicio, Búsqueda, Biblioteca, Radio y detalles de Artista/Álbum.

### D3. Dock de Reproducción estilo Apple Music Web
El reproductor se organiza en tres secciones horizontales principales:
1. **Izquierda**: Carátula de pista (44x44pt con esquinas redondeadas), título y artista en vertical, botón de favorito (corazón).
2. **Centro**: Botones de control (Anterior, Reproducir/Pausa, Siguiente) y la barra de progreso (scrubber) con etiquetas de tiempo transcrito y restante/duración.
3. **Derecha**: Deslizador de volumen (con icono de altavoz), modo shuffle, modo repeat, botón de letras y botón de cola.

## Risks / Trade-offs

- [Integrar `NavigationHistoryStore` en iOS/macOS puede competir con `NavigationStack` nativo] → Mitigación: Usar un gestor ligero de historial acoplado a la selección principal y sheets de detalle.
- [El scrubber de volumen en iOS requiere integración con `MPVolumeView` o control de ganancia `AVPlayer`] → Mitigación: Implementar control de volumen del player `AVPlayer.volume` de 0.0 a 1.0.

## Migration Plan

Cambio 100% de frontend SwiftUI. No requiere migración de persistencia Core Data ni backend.
