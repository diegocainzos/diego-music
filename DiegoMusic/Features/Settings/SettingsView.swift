import SwiftUI

struct SettingsView: View {
    @ObservedObject var playbackSettings: PlaybackSettings
    let resolverConfigured: Bool

    @State private var historyMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(eyebrow: "Control local", title: "Ajustes", color: DiegoTheme.red)

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
                    .foregroundStyle(DiegoTheme.ink.opacity(0.72))
                    settingLine("Motor", value: "AVPlayer")
                    settingLine("Vídeo embebido", value: "Desactivado")
                    settingLine("URL y token", value: "Configuración local protegida")
                }
                .bauhausCard(accent: resolverConfigured ? DiegoTheme.green : DiegoTheme.red)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Privacidad", systemImage: "lock.fill").font(.title2.bold())
                    settingLine("Biblioteca", value: "Solo local")
                    Toggle("Guardar historial local opcional", isOn: $playbackSettings.historyEnabled)
                        .tint(DiegoTheme.blue)
                    Button("Borrar historial local") {
                        do {
                            try playbackSettings.clearHistory()
                            historyMessage = "Historial local eliminado."
                        } catch {
                            historyMessage = "No se pudo borrar el historial local."
                        }
                    }
                    .buttonStyle(HiFiButtonStyle(color: DiegoTheme.blue))
                    if let historyMessage { Text(historyMessage).font(.caption) }
                    settingLine("Telemetría propia", value: "Desactivada")
                    settingLine("Inicio de sesión", value: "No requerido")
                }
                .bauhausCard(accent: DiegoTheme.blue)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Acerca de DiegoMusic", systemImage: "circle.hexagongrid.fill").font(.title2.bold())
                    Text("Proyecto privado. Usa YouTube Data API para el catálogo y un resolutor VPS privado para entregar audio temporal a AVPlayer.")
                        .font(.callout)
                    Text("No es una aplicación oficial ni está afiliada con YouTube o Google. El audio no se conserva permanentemente.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .bauhausCard(accent: DiegoTheme.yellow)
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private func settingLine(_ title: String, value: String) -> some View {
        HStack {
            Text(title).fontWeight(.semibold)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
