# Spec: Reproducción Offline & Detección de Red (nativa iOS/macOS)

## Reproducción inteligente en `AudioPlayerCoordinator`

El coordinador recibe una referencia al `OfflineDownloadManager`.
En el método `load(_:autoplay:resetRetryBudget:)`, antes de llamar al resolutor remoto:

```swift
private func load(_ item: MediaItem, ...) {
    // 1. Comprobar caché local primero
    if let localURL = await offlineManager.localURL(for: item.id) {
        let playerItem = AVPlayerItem(url: localURL)
        // Reproducir directamente, sin resolver VPS
        ...
        return
    }
    // 2. Resolver remotamente (flujo existente)
    let descriptor = try await resolver.resolve(videoID: item.id)
    ...
}
```

- La URL local es un `file://` URL del sandbox; AVPlayer los soporta nativamente.
- No se necesita `URL.createObjectURL` (eso es API web; aquí se usa la URL de fichero directamente).

---

## `NetworkMonitor` (Combine + NWPathMonitor)

```swift
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
```

- Framework: `Network` (disponible iOS 12+, macOS 10.14+; ya en el SDK).
- No requiere permisos adicionales en `Info.plist`.

---

## Comportamiento offline en el reproductor

Cuando `NetworkMonitor.isConnected == false`:

1. `AudioPlayerCoordinator.load(_:)` intenta la ruta local primero (igual que siempre).
2. Si no está descargada **y** no hay red → `playbackState = .failed`, mensaje sanitizado:
   `"Sin conexión. Descarga la canción para escucharla sin red."`
3. El `PlayerDock` muestra el botón de play deshabilitado con `.opacity(0.4)` si la pista no está descargada y no hay red.

---

## Filtrado de UI en modo offline

`SongsView`, `AlbumView` y `ListaView` observan `NetworkMonitor.isConnected`:

```swift
// Canción no descargada y sin red → fila atenuada + sin acción de play
.opacity(isOfflineAndNotDownloaded ? 0.4 : 1.0)
.allowsHitTesting(!isOfflineAndNotDownloaded)
```

Tooltip/overlay en tap inútil (solo iOS):
```swift
.overlay {
    if isOfflineAndNotDownloaded {
        Text("No disponible sin conexión")
            .font(.caption2)
            .padding(4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}
```

---

## `OfflineBanner`

```swift
struct OfflineBanner: View {
    @ObservedObject var monitor: NetworkMonitor

    var body: some View {
        if !monitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                Text("Sin conexión — Solo música descargada disponible")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(DiegoTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(DiegoTheme.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DiegoTheme.accent)
                    .frame(height: 1)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
```

Insertado en `RootView` como `.safeAreaInset(edge: .top)` en iPhone y como
bloque en el `VStack` del `desktopLayout` tras el `HeaderView`.

---

## Invariantes de seguridad mantenidos

- El `OfflineDownloadManager` descarga desde la URL opaca del VPS (que expira).
  El fichero guardado es el audio procesado, no la URL upstream de Googlevideo.
- La ruta de fichero local nunca se expone en mensajes de error al usuario.
- Los errores del downloader se sanitizan igual que en `AudioResolverClient`.
