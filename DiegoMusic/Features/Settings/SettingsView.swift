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
                Text("AJUSTES")
                    .dondaTitle(size: 20)
                    .foregroundStyle(DiegoTheme.textPrimary)

                // MARK: - Cuenta de Usuario (Backend)
                accountSection

                VStack(alignment: .leading, spacing: 14) {
                    Text("APARIENCIA")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text("Selecciona la apariencia preferida para la interfaz de la aplicación.")
                        .font(.callout)
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Picker("Tema de la interfaz", selection: $playbackSettings.themeMode) {
                        ForEach(AppThemeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(DiegoTheme.textPrimary)
                }
                .minimalCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("AUDIO PRIVADO")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)

                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(resolverConfigured ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                            .frame(width: 8, height: 8)
                        Text(resolverConfigured ? "Resolutor configurado" : "Resolutor pendiente de configuración")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(DiegoTheme.textPrimary)
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
                    Text("PRIVACIDAD")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)

                    settingLine("Biblioteca", value: "Solo local")
                    Toggle("Guardar historial local opcional", isOn: $playbackSettings.historyEnabled)
                        .tint(DiegoTheme.textPrimary)
                    Button {
                        do {
                            try library.clearHistory()
                            historyMessage = "Historial local eliminado."
                        } catch {
                            historyMessage = "No se pudo borrar el historial local."
                        }
                    } label: {
                        Text("BORRAR HISTORIAL LOCAL")
                            .dondaLabel()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if let historyMessage {
                        Text(historyMessage)
                            .dondaLabel()
                            .foregroundStyle(DiegoTheme.textSecondary)
                    }
                    settingLine("Telemetría propia", value: "Desactivada")
                    settingLine("Inicio de sesión", value: environment.authState.isAuthenticated ? "Activo" : "No iniciado")
                }
                .minimalCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("ACERCA DE DIEGOMUSIC")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)

                    Text("Proyecto privado. Usa YouTube Data API para el catálogo y un resolutor VPS privado para entregar audio temporal a AVPlayer.")
                        .font(.callout)
                        .foregroundStyle(DiegoTheme.textPrimary)
                    Text("No es una aplicación oficial ni está afiliada con YouTube o Google. El audio no se conserva permanentemente.")
                        .font(.caption)
                        .foregroundStyle(DiegoTheme.textSecondary)
                }
                .minimalCard()

                // MARK: - Almacenamiento Offline
                VStack(alignment: .leading, spacing: 14) {
                    Text("ALMACENAMIENTO OFFLINE")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)

                    settingLine("Canciones descargadas", value: "\(downloadManager.downloadedTracks.count)")
                    settingLine("Espacio ocupado", value: downloadManager.formattedTotalUsage)

                    Button(role: .destructive) {
                        showClearDownloadsConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("LIBERAR TODO EL ESPACIO")
                                .dondaLabel()
                        }
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
            Text("CUENTA DE USUARIO")
                .dondaLabel()
                .foregroundStyle(DiegoTheme.textSecondary)

            switch environment.authState {
            case .authenticated(let user):
                HStack(spacing: 16) {
                    ZStack {
                        Rectangle()
                            .fill(DiegoTheme.surface)
                            .frame(width: 44, height: 44)
                            .overlay(Rectangle().stroke(DiegoTheme.hairline, lineWidth: 1))
                        Text(String((user.fullName ?? user.email).prefix(1)).uppercased())
                            .dondaTitle(size: 16)
                            .foregroundStyle(DiegoTheme.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.fullName ?? "Usuario DiegoMusic")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(DiegoTheme.textPrimary)
                        Text(user.email)
                            .dondaLabel()
                            .foregroundStyle(DiegoTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        environment.logout()
                    } label: {
                        Text("CERRAR SESIÓN")
                            .dondaLabel()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(DiegoTheme.textPrimary)
                    Text("VERIFICANDO SESIÓN…")
                        .dondaLabel()
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
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                            Text("INICIAR SESIÓN / REGISTRARSE")
                                .dondaLabel()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .minimalCard()
    }

    private func settingLine(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .regular)).foregroundStyle(DiegoTheme.textPrimary)
            Spacer()
            Text(value).dondaLabel().foregroundStyle(DiegoTheme.textSecondary)
        }
    }
}
