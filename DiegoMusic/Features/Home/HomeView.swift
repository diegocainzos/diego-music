import SwiftUI

struct HomeView: View {
    let onStartSearch: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SectionHeader(eyebrow: "Escucha privada", title: "Sonido, forma y movimiento", color: DiegoTheme.accent)

                hero

                HStack(alignment: .top, spacing: 18) {
                    feature(title: "Explora", symbol: "waveform.path.ecg", text: "Busca música pública con metadatos de YouTube Data API.")
                    feature(title: "Protege", symbol: "shield.lefthalf.filled", text: "Controla reglas locales y recupera la reproducción con un toque.")
                    feature(title: "Colecciona", symbol: "square.stack.3d.up.fill", text: "Guarda favoritos y playlists solo en este dispositivo.")
                }
            }
            .padding(28)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DIEGO\nMUSIC")
                .font(.system(size: 58, weight: .black, design: .default))
                .tracking(-3)
                .foregroundStyle(DiegoTheme.textPrimary)
                .minimumScaleFactor(0.65)
            Text("Una máquina musical educativa, local y deliberadamente diferente.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DiegoTheme.textSecondary)
                .frame(maxWidth: 520, alignment: .leading)
            Button(action: onStartSearch) {
                Label("Buscar música", systemImage: "arrow.up.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("Abre la sección de búsqueda")
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .leading)
        .minimalCard()
    }

    private func feature(title: String, symbol: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.title).foregroundStyle(DiegoTheme.accent)
            Text(title).font(.title2.bold()).foregroundStyle(DiegoTheme.textPrimary)
            Text(text).font(.callout).foregroundStyle(DiegoTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalCard()
    }
}
