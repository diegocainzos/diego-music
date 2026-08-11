import SwiftUI

enum DiegoTheme {
    // MARK: - Tokens semánticos (estética Apple Music Web dark)

    /// Rojo vibrante Apple Music `#FA233C`
    static let accent = Color(red: 250 / 255.0, green: 35 / 255.0, blue: 60 / 255.0)
    /// Fondo oscuro base `#121212`
    static let background = Color(red: 18 / 255.0, green: 18 / 255.0, blue: 18 / 255.0)
    /// Superficie `#1E1E1E`
    static let surface = Color(red: 30 / 255.0, green: 30 / 255.0, blue: 30 / 255.0)
    /// Superficie de tarjetas `rgba(255,255,255,0.06)`
    static let cardSurface = Color.white.opacity(0.06)
    /// Overlay traslúcido efecto cristal
    static let glassMaterial: Material = .ultraThinMaterial

    /// Texto principal (blanco en interfaz oscura)
    static let textPrimary = Color.white
    /// Texto secundario / metadatos
    static let textSecondary = Color.white.opacity(0.6)

    /// Estado "reproduciendo" / verde
    static let green = Color(red: 0.12, green: 0.84, blue: 0.38)
    /// Errores
    static let red = Color(red: 250 / 255.0, green: 35 / 255.0, blue: 60 / 255.0)

    static let cornerRadius: CGFloat = 12
}

// MARK: - Tarjeta estilo Apple Music Glassmorphic

struct AppleMusicCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DiegoTheme.cornerRadius

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                ZStack {
                    DiegoTheme.cardSurface
                    Rectangle().fill(DiegoTheme.glassMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Tarjeta mínima heredada

struct MinimalCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(DiegoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
    }
}

extension View {
    func appleMusicCard(cornerRadius: CGFloat = DiegoTheme.cornerRadius) -> some View {
        modifier(AppleMusicCardModifier(cornerRadius: cornerRadius))
    }

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

// MARK: - Botón primario estilo Apple Music

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
