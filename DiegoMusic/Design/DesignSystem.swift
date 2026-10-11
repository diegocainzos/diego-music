import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DiegoTheme {
    // MARK: - Tokens semánticos (Donda)

    static let background = Color(
        light: Color(red: 0xFF / 255.0, green: 0xFF / 255.0, blue: 0xFF / 255.0),
        dark: Color(red: 0x00 / 255.0, green: 0x00 / 255.0, blue: 0x00 / 255.0)
    )

    static let surface = Color(
        light: Color(red: 0xFF / 255.0, green: 0xFF / 255.0, blue: 0xFF / 255.0),
        dark: Color(red: 0x00 / 255.0, green: 0x00 / 255.0, blue: 0x00 / 255.0)
    )

    static let textPrimary = Color(
        light: Color(red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x11 / 255.0),
        dark: Color(red: 0xE9 / 255.0, green: 0xE9 / 255.0, blue: 0xE9 / 255.0)
    )

    static let textSecondary = Color(
        light: Color(red: 0x8A / 255.0, green: 0x8A / 255.0, blue: 0x8A / 255.0),
        dark: Color(red: 0x66 / 255.0, green: 0x66 / 255.0, blue: 0x66 / 255.0)
    )

    static let hairline = Color(
        light: Color(red: 0xEC / 255.0, green: 0xEC / 255.0, blue: 0xEC / 255.0),
        dark: Color(red: 0x1B / 255.0, green: 0x1B / 255.0, blue: 0x1B / 255.0)
    )

    static let outline = Color(
        light: Color(red: 0xCF / 255.0, green: 0xCF / 255.0, blue: 0xCF / 255.0),
        dark: Color(red: 0x33 / 255.0, green: 0x33 / 255.0, blue: 0x33 / 255.0)
    )

    /// En el sistema Donda no hay color de acento propio: coincide con `textPrimary`.
    static let accent = textPrimary

    static let cardSurface = Color(
        light: Color.black.opacity(0.04),
        dark: Color.white.opacity(0.06)
    )

    static let green = Color(red: 0.12, green: 0.84, blue: 0.38)
    static let red = Color(red: 250 / 255.0, green: 45 / 255.0, blue: 72 / 255.0)

    static let cornerRadius: CGFloat = 0

    // MARK: - Adaptadores dinámicos por ColorScheme (Modo Blanco / Negro)

    static func backgroundColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0xFF / 255.0, green: 0xFF / 255.0, blue: 0xFF / 255.0)
            : Color(red: 0x00 / 255.0, green: 0x00 / 255.0, blue: 0x00 / 255.0)
    }

    static func background(for scheme: ColorScheme) -> Color {
        backgroundColor(for: scheme)
    }

    static func surfaceColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0xFF / 255.0, green: 0xFF / 255.0, blue: 0xFF / 255.0)
            : Color(red: 0x00 / 255.0, green: 0x00 / 255.0, blue: 0x00 / 255.0)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        surfaceColor(for: scheme)
    }

    static func textPrimaryColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x11 / 255.0)
            : Color(red: 0xE9 / 255.0, green: 0xE9 / 255.0, blue: 0xE9 / 255.0)
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        textPrimaryColor(for: scheme)
    }

    static func textSecondaryColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0x8A / 255.0, green: 0x8A / 255.0, blue: 0x8A / 255.0)
            : Color(red: 0x66 / 255.0, green: 0x66 / 255.0, blue: 0x66 / 255.0)
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        textSecondaryColor(for: scheme)
    }

    static func hairlineColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0xEC / 255.0, green: 0xEC / 255.0, blue: 0xEC / 255.0)
            : Color(red: 0x1B / 255.0, green: 0x1B / 255.0, blue: 0x1B / 255.0)
    }

    static func hairline(for scheme: ColorScheme) -> Color {
        hairlineColor(for: scheme)
    }

    static func outlineColor(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0xCF / 255.0, green: 0xCF / 255.0, blue: 0xCF / 255.0)
            : Color(red: 0x33 / 255.0, green: 0x33 / 255.0, blue: 0x33 / 255.0)
    }

    static func outline(for scheme: ColorScheme) -> Color {
        outlineColor(for: scheme)
    }

    static func accentColor(for scheme: ColorScheme) -> Color {
        textPrimaryColor(for: scheme)
    }

    static func accent(for scheme: ColorScheme) -> Color {
        textPrimary(for: scheme)
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

// MARK: - Tarjeta mínima adaptativa

struct MinimalCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(DiegoTheme.surfaceColor(for: colorScheme))
            .overlay(
                Rectangle()
                    .stroke(DiegoTheme.outlineColor(for: colorScheme), lineWidth: 1)
            )
            .clipShape(Rectangle())
    }
}

extension View {
    func minimalCard() -> some View {
        modifier(MinimalCardModifier())
    }
}

// MARK: - Modificadores tipográficos Donda

extension View {
    func dondaLabel() -> some View {
        font(.system(size: 11, design: .monospaced))
            .textCase(.uppercase)
            .tracking(1.4)
    }

    func dondaTitle(size: CGFloat = 20) -> some View {
        font(.system(size: size, weight: .regular).width(.condensed))
            .textCase(.uppercase)
            .tracking(2.4)
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

// MARK: - Botón primario Donda

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = DiegoTheme.accent
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let isDefaultPrimary = (color == DiegoTheme.accent || color == DiegoTheme.textPrimary)
        let fill = isDefaultPrimary ? DiegoTheme.textPrimaryColor(for: colorScheme) : color
        let labelColor = isDefaultPrimary ? DiegoTheme.backgroundColor(for: colorScheme) : Color.white

        return configuration.label
            .font(.system(.body, design: .default, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .foregroundStyle(labelColor)
            .background(configuration.isPressed ? fill.opacity(0.85) : fill)
            .overlay(
                Rectangle()
                    .stroke(DiegoTheme.outlineColor(for: colorScheme), lineWidth: 1)
            )
            .clipShape(Rectangle())
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
