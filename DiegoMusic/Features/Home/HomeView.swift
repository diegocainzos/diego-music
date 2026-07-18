import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateShapes = false
    let onStartSearch: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SectionHeader(eyebrow: "Escucha privada", title: "Sonido, forma y movimiento", color: DiegoTheme.red)

                hero

                HStack(alignment: .top, spacing: 18) {
                    feature(title: "Explora", symbol: "waveform.path.ecg", color: DiegoTheme.blue, text: "Busca música pública con metadatos de YouTube Data API.")
                    feature(title: "Protege", symbol: "shield.lefthalf.filled", color: DiegoTheme.red, text: "Controla reglas locales y recupera la reproducción con un toque.")
                    feature(title: "Colecciona", symbol: "square.stack.3d.up.fill", color: DiegoTheme.yellow, text: "Guarda favoritos y playlists solo en este dispositivo.")
                }
            }
            .padding(28)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateShapes = true
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DiegoTheme.ink)
            Circle()
                .fill(DiegoTheme.red)
                .frame(width: 210, height: 210)
                .offset(x: animateShapes ? 32 : -8, y: animateShapes ? -20 : 12)
            Rectangle()
                .fill(DiegoTheme.blue)
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(animateShapes ? 15 : -8))
                .offset(x: 230, y: -65)
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(DiegoTheme.yellow, style: StrokeStyle(lineWidth: 28, lineCap: .butt))
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(animateShapes ? 220 : 40))
                .offset(x: 390, y: -35)

            VStack(alignment: .leading, spacing: 14) {
                Text("DIEGO\nMUSIC")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .tracking(-3)
                    .foregroundStyle(DiegoTheme.paper)
                    .minimumScaleFactor(0.65)
                Text("Una máquina musical educativa, local y deliberadamente diferente.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DiegoTheme.cream)
                    .frame(maxWidth: 520, alignment: .leading)
                Button(action: onStartSearch) {
                    Label("Buscar música", systemImage: "arrow.up.right")
                }
                .buttonStyle(HiFiButtonStyle(color: DiegoTheme.yellow))
                .accessibilityHint("Abre la sección de búsqueda")
            }
            .padding(32)
        }
        .frame(minHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(DiegoTheme.ink, lineWidth: 3) }
    }

    private func feature(title: String, symbol: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.title).foregroundStyle(color)
            Text(title).font(.title2.bold())
            Text(text).font(.callout).foregroundStyle(DiegoTheme.ink.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bauhausCard(accent: color)
    }
}
