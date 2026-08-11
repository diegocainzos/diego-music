# Lyrics 03 — QA & Verification Spec

## Objetivo

Definir el checklist de pruebas, criterios de aceptación y proceso de verificación visual para la feature de Live Lyrics.

## Canción de prueba

- **Canción:** Coldplay - Yellow (Album: Parachutes)
- **Tiene syncedLyrics en LRCLIB:** ✅ (verificado, ID: 16233)
- **Duración:** ~267 segundos
- **Primera línea sincronizada:** `[00:33.80] Look at the stars`

## Checklist de criterios de aceptación

### API & Parser

- [ ] La petición a LRCLIB incluye la cabecera `User-Agent: AppleMusicClone/1.0 (https://github.com/app)`.
- [ ] `GET /api/get` se llama con `artist_name`, `track_name` extraídos del `MediaItem`.
- [ ] Si `/api/get` devuelve 404, se hace fallback a `/api/search`.
- [ ] El parser LRC convierte `[mm:ss.xx]` a segundos flotantes correctamente.
- [ ] Las líneas se ordenan por `startTime`.
- [ ] La caché evita peticiones duplicadas para la misma canción.

### Sincronización en tiempo real

- [ ] Al reproducir la canción, la línea activa se resalta brillantemente.
- [ ] El cambio de línea activa ocurre en el momento correcto (±0.5s).
- [ ] El autoscroll mantiene la línea actual centrada verticalmente de forma suave.
- [ ] El scroll no salta bruscamente sino que transiciona con `easeInOut`.
- [ ] La primera línea se centra correctamente (padding superior suficiente).
- [ ] La última línea se centra correctamente (padding inferior suficiente).

### Interacción

- [ ] Hacer clic en cualquier frase salta la canción exactamente a ese segundo.
- [ ] Tras el seek, la nueva línea activa se resalta inmediatamente.
- [ ] El autoscroll se reactiva tras el seek manual.

### Fallbacks

- [ ] Si la canción no tiene sincronización, muestra el texto plano (`plainLyrics`).
- [ ] Si no existe la letra en la API, muestra la pantalla de reserva elegante.
- [ ] Si la canción es instrumental, muestra el estado instrumental.
- [ ] Errores de red muestran un estado degradado sin crashear.

### Visual & Diseño

- [ ] La UI tiene el efecto de desenfoque/glassmorphism con la portada del álbum.
- [ ] La línea activa tiene tipografía bold, blanco puro y efecto glow.
- [ ] Las líneas inactivas son semitransparentes (`opacity ≈ 0.35`).
- [ ] La transición entre líneas es suave (animación CSS/SwiftUI).
- [ ] El fondo se oscurece lo suficiente para legibilidad del texto.

### Accesibilidad

- [ ] VoiceOver anuncia la línea activa.
- [ ] `accessibilityReduceMotion` desactiva animaciones de scroll.
- [ ] El contraste texto/fondo cumple WCAG AA (4.5:1 mínimo).

## Proceso de verificación

1. Compilar y ejecutar la app en simulador iOS o dispositivo.
2. Buscar "Coldplay - Yellow" y reproducir.
3. Abrir las letras desde el botón en el player dock o reproductor expandido.
4. Verificar que las líneas se resaltan en sincronía con el audio.
5. Tocar una línea adelante en las letras → verificar que el audio salta.
6. Tocar una línea atrás → verificar que el audio retrocede.
7. Buscar una canción sin letras en LRCLIB → verificar fallback elegante.
8. Tomar capturas de pantalla.

## Pruebas unitarias

### LRC Parser

```swift
func testParseLRC_basicFormat() {
    let input = "[00:33.80] Look at the stars\n[00:36.23] Look how they shine for you"
    let result = LRCParser.parse(input)
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].startTime, 33.80, accuracy: 0.01)
    XCTAssertEqual(result[0].text, "Look at the stars")
    XCTAssertEqual(result[1].startTime, 36.23, accuracy: 0.01)
}

func testParseLRC_millisecondFormat() {
    let input = "[01:23.456] Text with milliseconds"
    let result = LRCParser.parse(input)
    XCTAssertEqual(result[0].startTime, 83.456, accuracy: 0.001)
}

func testParseLRC_emptyLines() {
    let input = "[00:10.00] Line one\n[00:15.00] \n[00:20.00] Line three"
    let result = LRCParser.parse(input)
    XCTAssertEqual(result.count, 3)
    XCTAssertTrue(result[1].text.trimmingCharacters(in: .whitespaces).isEmpty)
}
```

### Title cleaner

```swift
func testCleanTitle_officialVideo() {
    XCTAssertEqual(cleanTitle("Yellow (Official Video)"), "Yellow")
}

func testCleanTitle_dashSeparated() {
    XCTAssertEqual(cleanTitle("Coldplay - Yellow"), "Yellow")
    // artist should be extracted separately
}
```

### Cache

```swift
func testCache_hitAfterFirstFetch() async {
    // First call should fetch, second should be cached
}
```
