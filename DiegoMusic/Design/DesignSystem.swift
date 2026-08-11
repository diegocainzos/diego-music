import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import SwiftUI

enum DiegoTheme {
    // MARK: - Tokens semánticos (estética Apple Music Web)

    /// Rojo vibrante Apple Music `#FA2D48` (RGB: 250, 45, 72)
    static let accent = Color(red: 250 / 255.0, green: 45 / 255.0, blue: 72 / 255.0)

    static let background = Color(
        light: Color.white,
        dark: Color.black
    )

    static let surface = Color(
        light: Color(red: 242 / 255.0, green: 242 / 255.0, blue: 247 / 255.0),
        dark: Color(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0)
    )

    static let cardSurface = Color(
        light: Color.black.opacity(0.04),
        dark: Color.white.opacity(0.06)
    )

    static let glassMaterial: Material = .ultraThinMaterial

    static let textPrimary = Color(
        light: Color.black,
        dark: Color.white
    )

    static let textSecondary = Color(
        light: Color.black.opacity(0.60),
        dark: Color.white.opacity(0.60)
    )

    static let textTertiary = Color(
        light: Color.black.opacity(0.35),
        dark: Color.white.opacity(0.35)
    )

    static let green = Color(red: 0.12, green: 0.84, blue: 0.38)
    static let red = Color(red: 250 / 255.0, green: 45 / 255.0, blue: 72 / 255.0)

    static let cornerRadius: CGFloat = 12

    // MARK: - Adaptadores dinámicos por ColorScheme (Modo Claro / Oscuro)

    static func backgroundColor(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.white : Color.black
    }

    static func background(for scheme: ColorScheme) -> Color {
        backgroundColor(for: scheme)
    }

    static func surfaceColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 242 / 255.0, green: 242 / 255.0, blue: 247 / 255.0) // #F2F2F7
            : Color(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0)    // #1C1C1E
    }

    static func surface(for scheme: ColorScheme) -> Color {
        surfaceColor(for: scheme)
    }

    static func textPrimaryColor(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black : Color.white
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        textPrimaryColor(for: scheme)
    }

    static func textSecondaryColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color.black.opacity(0.60)
            : Color.white.opacity(0.60)
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        textSecondaryColor(for: scheme)
    }

    static func cardStrokeColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color.black.opacity(0.06)
            : Color.white.opacity(0.08)
    }
}

extension Color {
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .light ? UIColor(light) : UIColor(dark)
        })
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        self = dark
        #endif
    }
}

// MARK: - Componente Logotipo Oficial Apple Music

/// Componente de logotipo oficial estilo Apple Music:
/// Fondo degradado rojo-rosa (`#FC3C44` -> `#FF2D55`) con icono de nota musical en blanco y texto "Music" en bold.
struct AppleMusicLogoView: View {
    var size: CGFloat = 28
    var showText: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 252 / 255.0, green: 60 / 255.0, blue: 68 / 255.0), // #FC3C44
                                Color(red: 255 / 255.0, green: 45 / 255.0, blue: 85 / 255.0)  // #FF2D55
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: Color(red: 252 / 255.0, green: 60 / 255.0, blue: 68 / 255.0).opacity(0.35), radius: 4, y: 2)

                Image(systemName: "music.note")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(.white)
            }

            if showText {
                HStack(spacing: 2) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: size * 0.65, weight: .semibold))
                    Text("Music")
                        .font(.system(size: size * 0.7, weight: .bold, design: .default))
                }
                .foregroundStyle(DiegoTheme.textPrimary)
            }
        }
    }
}

// MARK: - Tarjeta estilo Apple Music Glassmorphic

struct AppleMusicCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = DiegoTheme.cornerRadius

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                ZStack {
                    DiegoTheme.surfaceColor(for: colorScheme).opacity(colorScheme == .light ? 0.88 : 0.85)
                    Rectangle().fill(colorScheme == .light ? Material.regularMaterial : Material.ultraThinMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DiegoTheme.cardStrokeColor(for: colorScheme), lineWidth: 1)
            )
    }
}

// MARK: - Tarjeta mínima adaptativa

struct MinimalCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(DiegoTheme.surfaceColor(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
    }
}

extension View {
    func appleMusicCard(cornerRadius: CGFloat = DiegoTheme.cornerRadius) -> some View {
        modifier(AppleMusicCardModifier(cornerRadius: cornerRadius))
    }

    func glassCard(cornerRadius: CGFloat = DiegoTheme.cornerRadius) -> some View {
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption.bold())
                .tracking(1.5)
                .foregroundStyle(color)
            Text(title)
                .font(.title.bold())
                .foregroundStyle(DiegoTheme.textPrimaryColor(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
