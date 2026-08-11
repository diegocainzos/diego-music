import SwiftUI

/// Componente para importar playlists desde YouTube mediante URL o ID.
struct ImportYouTubePlaylistSheet: View {
    @ObservedObject var library: LibraryStore
    var youtubeService: (any YouTubeDataServicing)?
    @Environment(\.dismiss) private var dismiss

    @State private var playlistURLOrID: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    let onImport: ((LocalPlaylist) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Importar desde YouTube") {
                    TextField("Enlace o ID de playlist de YouTube", text: $playlistURLOrID)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Text("Ejemplo: https://www.youtube.com/playlist?list=PL... o ID directo 'PL...'")
                        .font(.caption)
                        .foregroundStyle(DiegoTheme.textSecondary)
                }

                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Obteniendo canciones de YouTube...")
                                .font(.subheadline)
                                .foregroundStyle(DiegoTheme.textSecondary)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(DiegoTheme.red)
                    }
                }
            }
            .navigationTitle("Importar Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") { importPlaylist() }
                        .font(.body.weight(.bold))
                        .disabled(isLoading || playlistURLOrID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func importPlaylist() {
        let input = playlistURLOrID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        guard let playlistID = extractPlaylistID(from: input) else {
            errorMessage = "No se pudo extraer el ID de playlist. Revisa el enlace."
            return
        }

        guard let youtubeService else {
            errorMessage = "El servicio de YouTube no está configurado."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let album = try await youtubeService.album(byPlaylistID: playlistID)
                guard !album.tracks.isEmpty else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "La playlist de YouTube está vacía o es privada."
                    }
                    return
                }

                let newPlaylist = try await MainActor.run {
                    let created = try library.createPlaylist(named: album.title)
                    for track in album.tracks {
                        try library.add(track, to: created)
                    }
                    return created
                }

                await MainActor.run {
                    isLoading = false
                    onImport?(newPlaylist)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error al importar la playlist de YouTube."
                }
            }
        }
    }

    private func extractPlaylistID(from input: String) -> String? {
        if input.contains("list=") {
            if let components = URLComponents(string: input),
               let listParam = components.queryItems?.first(where: { $0.name == "list" })?.value {
                return listParam
            }
            // Fallback con expresiones regulares
            if let range = input.range(of: "(?<=list=)[A-Za-z0-9_-]+", options: .regularExpression) {
                return String(input[range])
            }
        }
        // Si no contiene list=, asumir que el usuario introdujo directamente el ID (ej: PL... u OL...)
        if !input.contains("/") && !input.contains("?") {
            return input
        }
        return nil
    }
}
