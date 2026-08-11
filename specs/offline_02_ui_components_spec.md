# Spec: Componentes UI — Descargas Offline (SwiftUI nativo)

## Estados del botón de descarga

```
DownloadButtonState
  ├── .notDownloaded     → SF Symbol: "arrow.down.circle"         (color: textSecondary)
  ├── .queued            → SF Symbol: "clock"                     (color: textSecondary)
  ├── .downloading(0.0…1.0) → ProgressView circular (anillo)    (color: accent)
  ├── .downloaded        → SF Symbol: "arrow.down.circle.fill"    (color: green)
  └── .failed            → SF Symbol: "exclamationmark.circle"    (color: red)
```

---

## `DownloadButton` — Componente reutilizable

```swift
struct DownloadButton: View {
    let videoID: String
    @ObservedObject var downloadManager: OfflineDownloadManagerProxy
}
```

- Tamaño: 32×32 pt área táctil, icono 18 pt.
- Animación de transición `.symbolEffect(.bounce)` al pasar a `.downloaded`.
- Al pulsar en estado `.downloaded`: muestra `ConfirmationDialog` "Eliminar descarga".
- Accesibilidad: `accessibilityLabel` dinámico según estado.

---

## Puntos de integración en la UI

### Fila de canción — `LibraryTrackRow`

Añadir `DownloadButton` como tercer elemento de la fila (entre corazón y fin):

```
[Artwork] [Título/Artista] [♡] [↓] [···]
```

### Fila de canción de álbum — `AlbumTrackRow`

Añadir `DownloadButton` en el menú contextual (`.menu`) como acción "Descargar":

```swift
Button { downloadManager.enqueue(item) } label: {
    Label("Descargar", systemImage: "arrow.down.circle")
}
```

### Cabecera de Álbum / Playlist — `AlbumView` / `PlaylistsView`

Botón "Descargar todo" junto al botón de reproducción:

```
[▶ Reproducir]  [↓ Descargar todo]
```

El botón dispara `downloadManager.downloadPlaylist(items)`.
Muestra progreso global: `"Descargando X de Y…"`.

---

## Sección "Descargados" en `LibraryView`

Añadir tab/sección `LibrarySection.downloads = "Descargados"`:

```
Canciones | Álbumes | Artistas | Listas | Descargados
```

Contenido: lista de `DownloadedTrack` ordenada por `downloadedAt` desc.
Fila: igual que `LibraryTrackRow` con badge de tamaño ("3.2 MB").

Toggle "Solo descargados" en `SongsView`: filtra la lista de `SavedTrack`
a los que tienen `isDownloaded == true` según el manager.

---

## Banner "Sin conexión"

`OfflineBanner`: barra fina en la parte superior del contenido (debajo del header),
visible solo cuando `NetworkMonitor.isConnected == false`.

```swift
struct OfflineBanner: View {
    // "Sin conexión — Mostrando solo música descargada"
    // Fondo: DiegoTheme.surface, borde inferior accent
    // Desaparece con animación al recuperar la red
}
```

---

## Modal de Almacenamiento en `SettingsView`

Nueva sección `"Almacenamiento offline"` en la pantalla de Ajustes:

```
Espacio ocupado:   124 MB
Canciones:         47
[Liberar todo el espacio]   ← destructivo, con ConfirmationDialog
```

---

## Criterios de diseño

- Seguir `DiegoTheme` existente: `accent` (rojo), `green`, `textSecondary`.
- Animaciones: `.animation(.easeInOut(duration: 0.25), value: state)`.
- No introducir dependencias externas nuevas; solo SwiftUI + Combine.
- Respetar `@MainActor` en todas las vistas.
