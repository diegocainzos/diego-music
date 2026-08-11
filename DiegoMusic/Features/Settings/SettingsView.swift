import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var playbackSettings: PlaybackSettings
    let library: LibraryStore
    let resolverConfigured: Bool
    @ObservedObject var downloadManager: OfflineDownloadManager

    @State private var historyMessage: String?
    @State private var showClearDownloadsConfirm = false
    @State private var isShowingLoginSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(eyebrow: "Control local", title: "Ajustes", color: DiegoTheme.accent)

                // MARK: - Cuenta de Usuario (Backend)
                accountSection

                VStack(alignment: .leading, spacing: 14) {
                    Label("Apariencia", systemImage: "paintpalette.fill")
                        .font(.title2.bold())

                    Text("Selecciona la apariencia preferida para la interfaz de la aplicación.")
                        .font(.callout)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Picker("Tema de la interfaz", selection: $playbackSettings.themeMode) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .minimalCard()

                VStack(alignment: .leading, spacing: 14) {
                    Label("Audio privado", systemImage: "waveform.badge.shield.lefthalf.filled")
                        .font(.title2.bold())
                    HStack {
                        Circle()
                            .fill(resolverConfigured ? DiegoTheme.green : DiegoTheme.red)
                            .frame(width: 12, height: 12)
                        Text(resolverConfigured ? "Resolutor configurado" : "Resolutor pendiente de configuración")
                            .fontWeight(.semibold)
                    }
                    Text(
                        resolverConfigured
                            ? "Las canciones se resuelven en tu VPS y se reproducen de forma nativa con AVPlayer."
                            : "Añade AUDIO_RESOLVER_BASE_URL y AUDIO_RESOLVER_API_TOKEN a .env y regenera el proyecto."
                    )
                    .font(.callout)
                    .foregroundStyle(DiegoTheme.textSecondary)
                    settingLine("Motor", value: "AVPlayer")
                    settingLine("Vídeo embebido", value: "Desactivado")
                    settingLine("URL y token", value: "Configuración local protegida")
                }
                .minimalCard()

                VStack(alignment: .leading, spacing: 12) {
                    Label("Privacidad", systemImage: "lock.fill").font(.title2.bold())
                    settingLine("Biblioteca", value: "Solo local")
                    Toggle("Guardar historial local opcional", isOn: $playbackSettings.historyEnabled)
                        .tint(DiegoTheme.accent)
                    Button("Borrar historial local") {
                        do {
                            try library.clearHistory()
                            historyMessage = "Historial local eliminado."
                        } catch {
                            historyMessage = "No se pudo borrar el historial local."
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    if let historyMessage { Text(historyMessage).font(.caption) }
                    settingLine("Telemetría propia", value: "Desactivada")
                    settingLine("Inicio de sesión", value: environment.authState.isAuthenticated ? "Activo" : "No iniciado")
                }
                .minimalCard()

                VStack(alignment: .leading, spacing: 10) {
                    Label("Acerca de DiegoMusic", systemImage: "circle.hexagongrid.fill").font(.title2.bold())
                    Text("Proyecto privado. Usa YouTube Data API para el catálogo y un resolutor VPS privado para entregar audio temporal a AVPlayer.")
                        .font(.callout)
                    Text("No es una aplicación oficial ni está afiliada con YouTube o Google. El audio no se conserva permanentemente.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .minimalCard()

                // MARK: - Almacenamiento Offline
                VStack(alignment: .leading, spacing: 14) {
                    Label("Almacenamiento offline", systemImage: "arrow.down.circle.fill")
                        .font(.title2.bold())

                    settingLine("Canciones descargadas", value: "\(downloadManager.downloadedTracks.count)")
                    settingLine("Espacio ocupado", value: downloadManager.formattedTotalUsage)

                    Button(role: .destructive) {
                        showClearDownloadsConfirm = true
                    } label: {
                        Label("Liberar todo el espacio", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .confirmationDialog(
                        "Liberar todo el espacio",
                        isPresented: $showClearDownloadsConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Eliminar todas las descargas", role: .destructive) {
                            try? downloadManager.removeAllDownloads()
                        }
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Se borrarán \(downloadManager.downloadedTracks.count) canciones del dispositivo.")
                    }
                }
                .minimalCard()
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $isShowingLoginSheet) {
            LoginView()
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Cuenta de usuario", systemImage: "person.crop.circle.fill")
                .font(.title2.bold())

            switch environment.authState {
            case .authenticated(let user):
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(DiegoTheme.accent)
                            .frame(width: 48, height: 48)
                        Text(String((user.fullName ?? user.email).prefix(1)).uppercased())
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.fullName ?? "Usuario DiegoMusic")
                            .font(.headline)
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(DiegoTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        environment.logout()
                    } label: {
                        Text("Cerrar Sesión")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(PrimaryButtonStyle(color: DiegoTheme.red))
                }

            case .loading:
                HStack {
                    ProgressView()
                        .tint(DiegoTheme.accent)
                    Text("Verificando sesión...")
                        .font(.subheadline)
                        .foregroundStyle(DiegoTheme.textSecondary)
                }

            case .unauthenticated:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Conecta con tu servidor privado para sincronizar listas y preferencias.")
                        .font(.callout)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Button {
                        isShowingLoginSheet = true
                    } label: {
                        Label("Iniciar Sesión / Registrarse", systemImage: "lock.shield.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .minimalCard()
    }

    private func settingLine(_ title: String, value: String) -> some View {
        HStack {
            Text(title).fontWeight(.semibold)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
