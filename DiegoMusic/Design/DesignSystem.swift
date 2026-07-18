import SwiftUI

enum DiegoTheme {
    static let ink = Color(red: 0.09, green: 0.08, blue: 0.07)
    static let cream = Color(red: 0.95, green: 0.89, blue: 0.79)
    static let paper = Color(red: 0.99, green: 0.96, blue: 0.89)
    static let red = Color(red: 0.88, green: 0.22, blue: 0.17)
    static let yellow = Color(red: 0.96, green: 0.73, blue: 0.12)
    static let yellowText = Color(red: 0.43, green: 0.29, blue: 0.02)
    static let blue = Color(red: 0.08, green: 0.35, blue: 0.70)
    static let green = Color(red: 0.08, green: 0.45, blue: 0.31)

    static let cornerRadius: CGFloat = 10
    static let strokeWidth: CGFloat = 2
}

struct BauhausCardModifier: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(DiegoTheme.paper)
            .foregroundStyle(DiegoTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DiegoTheme.cornerRadius, style: .continuous)
                    .stroke(DiegoTheme.ink, lineWidth: DiegoTheme.strokeWidth)
            }
            .shadow(color: accent, radius: 0, x: 6, y: 6)
            .padding(.trailing, 6)
            .padding(.bottom, 6)
    }
}

extension View {
    func bauhausCard(accent: Color = DiegoTheme.red) -> some View {
        modifier(BauhausCardModifier(accent: accent))
    }
}

struct HiFiButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let color: Color

    init(color: Color = DiegoTheme.yellow) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .bold))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(DiegoTheme.ink)
            .background(configuration.isPressed ? color.opacity(0.65) : color)
            .clipShape(Capsule())
            .overlay { Capsule().stroke(DiegoTheme.ink, lineWidth: 2) }
            .shadow(color: DiegoTheme.ink, radius: 0, x: configuration.isPressed ? 1 : 3, y: configuration.isPressed ? 1 : 3)
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.65),
                value: configuration.isPressed
            )
    }
}

struct RecordPlaceholder: View {
    let color: Color
    var rotation: Angle = .zero

    var body: some View {
        ZStack {
            Circle().fill(DiegoTheme.ink)
            ForEach(0..<4, id: \.self) { ring in
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .padding(CGFloat(ring * 8 + 6))
            }
            Circle().fill(color).frame(width: 34, height: 34)
            Circle().fill(DiegoTheme.paper).frame(width: 8, height: 8)
            Rectangle()
                .fill(DiegoTheme.paper.opacity(0.7))
                .frame(width: 2, height: 32)
                .offset(y: -22)
        }
        .rotationEffect(rotation)
        .accessibilityHidden(true)
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption.bold())
                .tracking(2)
                .foregroundStyle(color)
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(DiegoTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
