# Lyrics 02 — UI Component: Apple Music Live Lyrics

## Objetivo

Reconstruir la vista de letras sincronizadas con la estética y comportamiento de **Apple Music Live Lyrics**: línea activa brillante, autoscroll centrado, tap-to-seek, y fondo glassmorphism con la portada del álbum.

## Arquitectura de la vista

### Integración en PlayerDock

1. **Botón de letras** ya existe en la barra del reproductor y en el reproductor expandido (icono `quote.bubble`).
2. Al pulsar, se abre un **sheet** que ahora contendrá la nueva `LyricsView` mejorada.
3. La `LyricsView` recibe:
   - `LyricsService` (con `LRCLibLyricsProvider`).
   - `MediaItem` actual.
   - `currentTime: Double` (binding al progreso del player).
   - `onSeek: (Double) -> Void` — callback para tap-to-seek.

### Cambio clave: Binding reactivo para currentTime

El `LyricsView` actual recibe `currentTime` como `let` (valor snapshot). Para autoscroll en tiempo real, necesita un binding reactivo. Opciones:
- Pasar `@ObservedObject var player: AudioPlayerCoordinator` directamente.
- O usar `@Binding var currentTime: Double` con timer.

**Decisión:** Pasar el `player` directamente para acceder a `currentTime` y `seek(toSeconds:)`.

## Diseño Visual — Apple Music Live Lyrics

### Fondo

```swift
ZStack {
    // Portada del álbum escalada y difuminada
    TrackArtwork(url: item.thumbnailURL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .blur(radius: 60)
        .brightness(-0.3)
        .saturation(1.4)
        .scaleEffect(1.2)
        .clipped()
    
    // Overlay oscuro para legibilidad
    Color.black.opacity(0.4)
}
.ignoresSafeArea()
```

### Tipografía y Líneas

| Estado | Font | Color | Opacidad | Efecto |
|--------|------|-------|----------|--------|
| **Línea activa** | `.title.bold()` | `.white` | `1.0` | Shadow glow blanco suave |
| **Líneas pasadas** | `.title3.weight(.medium)` | `.white` | `0.35` | Ninguno |
| **Líneas futuras** | `.title3.weight(.medium)` | `.white` | `0.35` | Ninguno |

### Efecto Glow en línea activa

```swift
Text(line.text)
    .shadow(color: .white.opacity(0.6), radius: 8, x: 0, y: 0)
    .shadow(color: .white.opacity(0.3), radius: 16, x: 0, y: 0)
```

### Transiciones

```swift
.animation(.easeInOut(duration: 0.3), value: activeIndex)
```

## Autoscroll

- Usar `ScrollViewReader` + `scrollTo(id:, anchor: .center)` con `withAnimation(.easeInOut(duration: 0.4))`.
- Respetar `accessibilityReduceMotion`: si está activo, scroll sin animación.
- El scroll se dispara cada vez que `activeIndex` cambia.
- Añadir padding vertical de `UIScreen.main.bounds.height / 2` arriba y abajo para que la primera y última línea puedan centrarse.

## Tap-to-Seek

Cada línea de letra es un botón:

```swift
Button {
    player.seek(toSeconds: line.startTime ?? 0)
} label: {
    Text(line.text)
        // ... estilos
}
.buttonStyle(.plain)
```

Al pulsar:
1. Se llama `player.seek(toSeconds: line.startTime)`.
2. El `currentTime` se actualiza → `activeIndex` cambia → autoscroll reposiciona.

## Fallbacks visuales

### Plain lyrics (sin timestamps)

- Mostrar todo el texto con scroll manual.
- Sin highlight de línea activa.
- Tipografía `.body` con opacidad completa.
- Indicador sutil: "Letras sin sincronización disponible".

### No lyrics available

```swift
VStack(spacing: 16) {
    Image(systemName: "music.note")
        .font(.system(size: 48))
        .foregroundStyle(.white.opacity(0.4))
    Text("Letra no disponible")
        .font(.title2.bold())
        .foregroundStyle(.white.opacity(0.7))
    Text("No se encontraron letras para esta canción")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.4))
}
```

### Instrumental

```swift
VStack(spacing: 16) {
    Image(systemName: "music.quarternote.3")
        .font(.system(size: 48))
        .foregroundStyle(.white.opacity(0.5))
    Text("Instrumental")
        .font(.title2.bold())
        .foregroundStyle(.white.opacity(0.7))
}
```

### Loading

- `ProgressView` con tint blanco sobre fondo difuminado.

## Estado de la vista

```swift
enum LyricsDisplayState {
    case loading
    case synced([LyricsLine])
    case plain(String)
    case instrumental
    case notFound
    case error(String)
}
```

## Header del sheet

- Barra de navegación con:
  - Título: nombre de la canción (truncado).
  - Botón "Cerrar" a la izquierda.
  - Mini artwork + info del artista opcionalmente.

## Accesibilidad

- `accessibilityLabel("Letras")` en el contenedor.
- `accessibilityValue` con el texto de la línea activa.
- VoiceOver anuncia cambios de línea activa.
- Soporte de Dynamic Type.
- Contraste suficiente (blanco sobre fondo oscurecido).

## Compatibilidad

- iOS 17+ / iPadOS 17+ / macOS 14.8.5+
- Orientación portrait y landscape.
- Adaptar padding en iPad (horizontalSizeClass).
