import SwiftUI

// MARK: - DownloadButton

/// Botón de descarga al estilo Apple Music con estados visuales animados.
/// Muestra flecha de descarga → anillo de progreso → badge descargado.
struct DownloadButton: View {
    let item: MediaItem
    @ObservedObject var downloadManager: OfflineDownloadManager
    let resolver: any AudioStreamResolving

    @State private var showDeleteConfirm = false

    private var state: DownloadState {
        downloadManager.states[item.id] ?? .notDownloaded
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            stateIcon
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .confirmationDialog(
            "Eliminar descarga",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                try? downloadManager.removeDownload(videoID: item.id)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrará \"\(item.title)\" del almacenamiento local.")
        }
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    // MARK: - Icono por estado

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DiegoTheme.textSecondary)

        case .queued:
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DiegoTheme.textSecondary)

        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(DiegoTheme.textSecondary.opacity(0.25), lineWidth: 2.5)
                    .frame(width: 20, height: 20)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DiegoTheme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
            }

        case .downloaded:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DiegoTheme.green)
                .symbolEffect(.bounce, value: state == .downloaded)

        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DiegoTheme.accent)
        }
    }

    // MARK: - Interacción

    private func handleTap() {
        switch state {
        case .notDownloaded, .failed:
            downloadManager.enqueue(item, resolver: resolver)
        case .downloaded:
            showDeleteConfirm = true
        case .queued, .downloading:
            break // No cancelar descargas en curso (simplificación deliberada)
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .notDownloaded: return "Descargar \(item.title)"
        case .queued: return "En cola para descargar \(item.title)"
        case .downloading(let p): return "Descargando \(item.title), \(Int(p * 100))%"
        case .downloaded: return "Descargado. Tocar para eliminar \(item.title)"
        case .failed: return "Error al descargar \(item.title). Tocar para reintentar"
        }
    }
}

// MARK: - DownloadAllButton

/// Botón "Descargar todo" para la cabecera de álbum / playlist.
struct DownloadAllButton: View {
    let items: [MediaItem]
    @ObservedObject var downloadManager: OfflineDownloadManager
    let resolver: any AudioStreamResolving

    private var allDownloaded: Bool {
        !items.isEmpty && items.allSatisfy { downloadManager.states[$0.id] == .downloaded }
    }

    private var anyInProgress: Bool {
        items.contains {
            if case .downloading = downloadManager.states[$0.id] { return true }
            return downloadManager.states[$0.id] == .queued
        }
    }

    private var downloadedCount: Int {
        items.filter { downloadManager.states[$0.id] == .downloaded }.count
    }

    var body: some View {
        Button {
            if !allDownloaded {
                downloadManager.downloadBatch(items, resolver: resolver)
            }
        } label: {
            HStack(spacing: 6) {
                if anyInProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DiegoTheme.accent)
                    Text("Descargando \(downloadedCount) de \(items.count)…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DiegoTheme.accent)
                } else if allDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(DiegoTheme.green)
                    Text("Descargado")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DiegoTheme.green)
                } else {
                    Image(systemName: "arrow.down.circle")
                    Text("Descargar todo")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DiegoTheme.surface)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(DiegoTheme.textPrimary.opacity(0.12), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(allDownloaded || anyInProgress)
        .animation(.easeInOut(duration: 0.25), value: allDownloaded)
        .animation(.easeInOut(duration: 0.25), value: anyInProgress)
    }
}

// MARK: - OfflineBanner

/// Banner discreto estilo iOS que aparece cuando no hay conexión de red.
struct OfflineBanner: View {
    @ObservedObject var monitor: NetworkMonitor

    var body: some View {
        if !monitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption.weight(.semibold))
                Text("Sin conexión — Solo música descargada disponible")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(DiegoTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
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
