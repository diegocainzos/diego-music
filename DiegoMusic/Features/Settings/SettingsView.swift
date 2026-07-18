import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: ShieldSettings
    @ObservedObject var playbackSettings: PlaybackSettings
    @ObservedObject var blocker: ContentBlocker
    let onApply: () -> Void

    @State private var importingRules = false
    @State private var showingLab = false
    @State private var importMessage: String?
    @State private var historyMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(eyebrow: "Control local", title: "Ajustes", color: DiegoTheme.red)

                VStack(alignment: .leading, spacing: 16) {
                    Label("PrivacyShield", systemImage: "shield.lefthalf.filled")
                        .font(.title2.bold())
                    Picker("Modo", selection: modeBinding) {
                        ForEach(ShieldMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(settings.mode.explanation)
                        .font(.callout)
                        .foregroundStyle(DiegoTheme.ink.opacity(0.7))
                    shieldStatus

                    HStack {
                        Button("Importar reglas JSON") { importingRules = true }
                            .buttonStyle(HiFiButtonStyle(color: DiegoTheme.blue))
                        if settings.customRulesData != nil {
                            Button("Quitar lista importada") {
                                settings.clearCustomRules()
                                onApply()
                            }
                            .buttonStyle(HiFiButtonStyle(color: DiegoTheme.red))
                        }
                        Button("Abrir laboratorio") { showingLab = true }
                            .buttonStyle(HiFiButtonStyle(color: DiegoTheme.yellow))
                    }
                    if let importMessage { Text(importMessage).font(.caption) }
                }
                .bauhausCard(accent: DiegoTheme.red)

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
                    settingLine("Clave API", value: "Configuración local protegida")
                }
                .bauhausCard(accent: DiegoTheme.blue)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Acerca de DiegoMusic", systemImage: "circle.hexagongrid.fill").font(.title2.bold())
                    Text("Proyecto educativo privado. Usa YouTube Data API y YouTube IFrame Player API; no es una aplicación oficial ni está afiliada con YouTube o Google.")
                        .font(.callout)
                    Text("El bloqueo sobre contenido real es de mejor esfuerzo: las reglas agresivas pueden necesitar ajustes cuando cambie la infraestructura del reproductor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .bauhausCard(accent: DiegoTheme.yellow)
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .fileImporter(isPresented: $importingRules, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                try settings.importRules(from: url)
                importMessage = "Lista importada y validada localmente."
                onApply()
            } catch {
                importMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo importar la lista."
            }
        }
        .sheet(isPresented: $showingLab) {
            ControlledShieldTestView(blocker: blocker)
                .frame(idealWidth: 620, idealHeight: 500)
        }
    }

    private var modeBinding: Binding<ShieldMode> {
        Binding(
            get: { settings.mode },
            set: { settings.mode = $0; onApply() }
        )
    }

    @ViewBuilder
    private var shieldStatus: some View {
        switch blocker.state {
        case .idle:
            Label("Preparado", systemImage: "circle")
        case .compiling:
            Label("Compilando reglas…", systemImage: "gearshape.2").foregroundStyle(DiegoTheme.blue)
        case let .active(ruleCount):
            Label("Activo: \(ruleCount) reglas", systemImage: "checkmark.shield.fill").foregroundStyle(DiegoTheme.green)
        case .disabled:
            Label("Sin reglas instaladas", systemImage: "shield.slash").foregroundStyle(.secondary)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.shield.fill").foregroundStyle(DiegoTheme.red)
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
