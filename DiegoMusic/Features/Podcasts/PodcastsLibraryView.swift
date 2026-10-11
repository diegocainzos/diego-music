import SwiftUI

/// Vista de programas de podcast seguidos en la biblioteca (Donda).
struct PodcastsLibraryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var navState: NavigationState
    var library: LibraryStore? = nil

    @State private var shows: [PodcastShow] = []

    private var currentLibrary: LibraryStore {
        library ?? environment.library
    }

    var body: some View {
        Group {
            if shows.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Text("NO SIGUES NINGÚN PODCAST. BÚSCALO Y PULSA SEGUIR.")
                        .dondaLabel()
                        .foregroundStyle(DiegoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(shows) { show in
                            Button {
                                navState.navigate(to: .podcastDetail(channelID: show.channelID, title: show.title))
                            } label: {
                                HStack(spacing: 14) {
                                    AsyncImage(url: show.thumbnailURL) { phase in
                                        switch phase {
                                        case let .success(image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            DiegoTheme.background
                                        }
                                    }
                                    .frame(width: 52, height: 52)
                                    .clipped()
                                    .overlay(
                                        Rectangle()
                                            .stroke(DiegoTheme.hairline, lineWidth: 1)
                                    )

                                    Text(show.title)
                                        .dondaLabel()
                                        .foregroundStyle(DiegoTheme.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(DiegoTheme.background)
        .onAppear {
            reload()
        }
    }

    private func reload() {
        shows = currentLibrary.followedShows()
    }
}
