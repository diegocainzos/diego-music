# Spec: Almacenamiento Offline — Arquitectura Nativa iOS/macOS

## Contexto

DiegoMusic es una app nativa Swift/SwiftUI con AVPlayer. El almacenamiento offline
usa el sistema de ficheros del sandbox de iOS/macOS (no IndexedDB, que es tecnología web).
Los metadatos se persisten en Core Data; los datos de audio en el directorio
`Application Support/DiegoMusic/Downloads/`.

---

## Modelo de Datos Core Data — `DownloadedTrack`

| Atributo           | Tipo     | Notas                                        |
|--------------------|----------|----------------------------------------------|
| `videoID`          | String   | PK (11 chars YouTube ID)                     |
| `title`            | String   |                                              |
| `channelTitle`     | String   |                                              |
| `thumbnailURL`     | String?  | URL de la miniatura remota                   |
| `localFilePath`    | String`  | Ruta relativa al directorio Downloads        |
| `fileSizeBytes`    | Int64    | Tamaño real en disco                         |
| `downloadedAt`     | Date     |                                              |
| `contentType`      | String   | `audio/mp4`, `audio/mpeg`, etc.              |

---

## `OfflineDownloadManager` (actor Swift)

Actor aislado para serializar operaciones de I/O. El `AudioPlayerCoordinator`
lo consulta antes de cada `resolve()`.

### Interfaz pública

```swift
actor OfflineDownloadManager {
    // Estado observable publicado en MainActor
    func downloadTrack(_ item: MediaItem, resolver: AudioStreamResolving) async throws
    func downloadPlaylist(_ items: [MediaItem], resolver: AudioStreamResolving) async
    func removeDownload(videoID: String) async throws
    func isDownloaded(videoID: String) async -> Bool
    func localURL(for videoID: String) async -> URL?
    var downloadedVideoIDs: Set<String> { get async }
    var totalDiskUsageBytes: Int64 { get async }
}
```

### Cola de descargas

- Descargas en serie (una a la vez) para no saturar el resolutor VPS.
- `DownloadState` por pista: `.idle | .queued | .downloading(progress: Double) | .downloaded | .failed(String)`.
- Progreso publicado via `AsyncStream<DownloadProgressEvent>`.

### Flujo de descarga de una pista

1. Resolver URL opaca → `resolver.resolve(videoID:)`.
2. `URLSession.data(for:)` con delegado de progreso (`URLSessionDataDelegate`).
3. Escribir a fichero temporal → `FileManager.default.moveItem(at:to:)` (atómico).
4. Guardar registro `DownloadedTrackRecord` en Core Data.
5. Emitir evento `.downloaded`.

### Manejo de errores

- `DownloadError.quotaExceeded` si `URLError.fileDoesNotExist` o código 507.
- Reintentos automáticos: máx. 2, con backoff de 3 s.
- Error final visible en UI sin exponer rutas internas.

---

## Directorio de almacenamiento

```
<AppSupportDir>/DiegoMusic/Downloads/<videoID>.<ext>
```

- Excluido de iCloud Backup (`isExcludedFromBackupKey = true`).
- En macOS, excluido de Spotlight con `.xattrName("com.apple.metadata:_kMDItemUserTags")` si precisa.

---

## Storage Estimate

```swift
func totalDiskUsageBytes() async -> Int64 {
    // Sum of fileSizeBytes from DownloadedTrackRecord Core Data fetch
}

func availableDiskSpace() -> Int64? {
    // FileManager.default.attributesOfFileSystem(forPath:)[.systemFreeSize]
}
```

Expuesto en `SettingsView` como sección "Almacenamiento Offline".
