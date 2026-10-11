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
                .font(.system(size: 16))
                .foregroundStyle(DiegoTheme.textSecondary)

        case .queued:
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundStyle(DiegoTheme.textSecondary)

        case .downloading(let progress):
            ZStack {
                Rectangle()
                    .stroke(DiegoTheme.outline, lineWidth: 1)
                    .frame(width: 16, height: 16)
                Rectangle()
                    .fill(DiegoTheme.textPrimary)
                    .frame(width: max(2, 16 * CGFloat(progress)), height: 16)
            }

        case .downloaded:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(DiegoTheme.textPrimary)

        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16))
                .foregroundStyle(DiegoTheme.textSecondary)
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

/// Botón "Descargar todo" para la cabecera de álbum / playlist en Donda.
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
                downloadManager.enqueueBatch(items, resolver: resolver)
            }
        } label: {
            HStack(spacing: 6) {
                if anyInProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DiegoTheme.textPrimary)
                    Text("DESCARGANDO \(downloadedCount)/\(items.count)")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                } else if allDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DiegoTheme.textPrimary)
                    Text("DESCARGADO")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textPrimary)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(DiegoTheme.textPrimary)
                    Text("DESCARGAR TODO")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textPrimary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DiegoTheme.background)
            .overlay(
                Rectangle()
                    .stroke(DiegoTheme.outline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(allDownloaded || anyInProgress)
        .animation(.easeInOut(duration: 0.25), value: allDownloaded)
        .animation(.easeInOut(duration: 0.25), value: anyInProgress)
    }
}

// MARK: - OfflineBanner

/// Banner discreto que aparece cuando no hay conexión de red.
struct OfflineBanner: View {
    @ObservedObject var monitor: NetworkMonitor

    var body: some View {
        if !monitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12))
                Text("SIN CONEXIÓN — SOLO MÚSICA DESCARGADA DISPONIBLE")
                    .dondaLabel()
            }
            .foregroundStyle(DiegoTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(DiegoTheme.background)
            .overlay(
                Rectangle()
                    .stroke(DiegoTheme.hairline, lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
