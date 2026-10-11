import SwiftUI

struct EmptyStateView: View {
    let title: String
    let symbol: String
    let description: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(
        title: String,
        symbol: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.symbol = symbol
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(DiegoTheme.textSecondary)
            Text(title)
                .dondaTitle(size: 18)
                .foregroundStyle(DiegoTheme.textPrimary)
            Text(description)
                .font(.callout)
                .foregroundStyle(DiegoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .dondaLabel()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(32)
        .accessibilityElement(children: .combine)
    }
}
