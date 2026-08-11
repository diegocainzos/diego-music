import SwiftUI

enum DiegoTheme {
    // MARK: - Tokens semánticos (estética minimal tipo Apple Music)

    /// Fondo claro base, similar a `systemBackground`.
    static let background = Color(red: 0.96, green: 0.96, blue: 0.97)
    /// Superficie de tarjetas.
    static let surface = Color(red: 1.0, green: 1.0, blue: 1.0)
    /// Texto principal.
    static let textPrimary = Color(red: 0.10, green: 0.10, blue: 0.11)
    /// Texto secundario / metadatos.
    static let textSecondary = Color.secondary
    /// Acento único (rojo actual de DiegoMusic, conservado).
    static let accent = Color(red: 0.88, green: 0.22, blue: 0.17)
    /// Estado "reproduciendo".
    static let green = Color(red: 0.08, green: 0.45, blue: 0.31)
    /// Errores.
    static let red = Color(red: 0.88, green: 0.22, blue: 0.17)

    static let cornerRadius: CGFloat = 16
}

// MARK: - Tarjeta mínima

struct MinimalCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(DiegoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
    }
}

extension View {
    func minimalCard() -> some View {
        modifier(MinimalCardModifier())
    }
}

// MARK: - Margen horizontal adaptativo

/// Aplica un margen horizontal que se adapta al `horizontalSizeClass`:
/// 16pt en pantallas compactas (iPhone) y 28pt en regulares (iPad/macOS).
struct ResponsiveHorizontalMarginModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        switch sizeClass {
        case .compact:
            content.padding(.horizontal, 16)
        default:
            content.padding(.horizontal, 28)
        }
    }
}

extension View {
    func responsiveHorizontalPadding() -> some View {
        modifier(ResponsiveHorizontalMarginModifier())
    }
}

// MARK: - Botón primario

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = DiegoTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .foregroundStyle(.white)
            .background(configuration.isPressed ? color.opacity(0.85) : color)
            .clipShape(Capsule())
    }
}

// MARK: - Cabecera de sección

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(color)
            Text(title)
                .font(.title.bold())
                .foregroundStyle(DiegoTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
