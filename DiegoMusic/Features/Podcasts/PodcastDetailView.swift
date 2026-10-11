import SwiftUI

/// Vista de detalle de un podcast (marcador de posición Donda).
struct PodcastDetailView: View {
    let channelID: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .dondaTitle(size: 20)
                .foregroundStyle(DiegoTheme.textPrimary)

            Text("Episodios")
                .dondaLabel()
                .foregroundStyle(DiegoTheme.textSecondary)

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DiegoTheme.background)
    }
}
