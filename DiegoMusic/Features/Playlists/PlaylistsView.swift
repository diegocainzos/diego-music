import SwiftUI

struct CreatePlaylistSheet: View {
    @ObservedObject var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var errorMessage: String?
    let onCreate: ((LocalPlaylist) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles de la Playlist") {
                    TextField("Nombre de la playlist", text: $name)
                    TextField("Descripción (opcional)", text: $descriptionText)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(DiegoTheme.red)
                    }
                }
            }
            .navigationTitle("Nueva Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") { savePlaylist() }
                        .font(.body.weight(.bold))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func savePlaylist() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let newPlaylist = try library.createPlaylist(named: trimmed)
            onCreate?(newPlaylist)
            dismiss()
        } catch {
            errorMessage = "No se pudo crear la playlist."
        }
    }
}

struct PlaylistsView: View {
    @ObservedObject var library: LibraryStore
    @State private var newName = ""
    @State private var expandedPlaylists: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var isShowingCreateSheet = false
    @State private var isShowingImportSheet = false
    let onPlay: (MediaItem) -> Void
    var onPlayQueue: (([MediaItem], Int) -> Void)? = nil
    var youtubeService: (any YouTubeDataServicing)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionHeader(eyebrow: "Secuencias locales", title: "Playlists", color: DiegoTheme.accent)
                Spacer()
                Button {
                    isShowingCreateSheet = true
                } label: {
                    Label("Crear", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    isShowingImportSheet = true
                } label: {
                    Label("Importar", systemImage: "arrow.down.doc.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            HStack {
                TextField("Nombre de la nueva playlist", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(createPlaylist)
                Button(action: createPlaylist) { Label("Crear", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(DiegoTheme.red)
            }

            if library.playlists.isEmpty {
                EmptyStateView(
                    title: "Sin playlists",
                    symbol: "music.note.list",
                    description: "Crea una mezcla local para empezar."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(library.playlists) { playlist in
                            DisclosureGroup(isExpanded: expandedBinding(for: playlist.id)) {
                                VStack(spacing: 8) {
                                    if playlist.entries.isEmpty {
                                        Text("Añade elementos desde Búsqueda.")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    let sortedEntries = playlist.entries.sorted(by: { $0.position < $1.position })
                                    ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                                        HStack(spacing: 10) {
                                            Button {
                                                if let onPlayQueue {
                                                    onPlayQueue(sortedEntries.map(\.mediaItem), index)
                                                } else {
                                                    onPlay(entry.mediaItem)
                                                }
                                            } label: {
                                                VStack(alignment: .leading) {
                                                    Text(entry.title).font(.headline).lineLimit(1)
                                                    Text(entry.channelTitle).font(.caption).foregroundStyle(.secondary)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .buttonStyle(.plain)
                                            Button { move(entry, in: playlist, by: -1) } label: { Image(systemName: "arrow.up") }
                                                .disabled(index == 0)
                                                .accessibilityLabel("Subir elemento")
                                            Button { move(entry, in: playlist, by: 1) } label: { Image(systemName: "arrow.down") }
                                                .disabled(index == playlist.entries.count - 1)
                                                .accessibilityLabel("Bajar elemento")
                                            Button { remove(entry, from: playlist) } label: { Image(systemName: "trash") }
                                                .accessibilityLabel("Eliminar de la playlist")
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.top, 12)
                            } label: {
                                HStack {
                                    Circle().fill(DiegoTheme.accent).frame(width: 46, height: 46)
                                    VStack(alignment: .leading) {
                                        Text(playlist.name).font(.title3.bold())
                                        Text("\(playlist.entries.count) elementos").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button { delete(playlist) } label: { Image(systemName: "trash") }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Eliminar playlist")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .minimalCard()
                        }
                    }
                }
            }
        }
        .padding(28)
        .sheet(isPresented: $isShowingCreateSheet) {
            CreatePlaylistSheet(library: library) { created in
                expandedPlaylists.insert(created.id)
            }
        }
        .sheet(isPresented: $isShowingImportSheet) {
            ImportYouTubePlaylistSheet(library: library, youtubeService: youtubeService) { created in
                expandedPlaylists.insert(created.id)
            }
        }
    }

    private func expandedBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedPlaylists.contains(id) },
            set: { expanded in
                if expanded { expandedPlaylists.insert(id) }
                else { expandedPlaylists.remove(id) }
            }
        )
    }

    private func createPlaylist() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            _ = try library.createPlaylist(named: name)
            TelemetryLogger.shared.recordEvent(type: "playlist_create", data: ["name": name])
            newName = ""
            errorMessage = nil
        } catch {
            errorMessage = "No se pudo crear la playlist."
        }
    }

    private func remove(_ entry: PlaylistEntry, from playlist: LocalPlaylist) {
        do {
            try library.remove(entry, from: playlist)
            TelemetryLogger.shared.recordEvent(type: "playlist_remove_track", data: ["playlist_name": playlist.name, "track_title": entry.title])
            errorMessage = nil
        }
        catch { errorMessage = "No se pudo eliminar el elemento." }
    }

    private func move(_ entry: PlaylistEntry, in playlist: LocalPlaylist, by offset: Int) {
        do {
            try library.move(entry, in: playlist, by: offset)
            TelemetryLogger.shared.recordEvent(type: "playlist_reorder", data: ["playlist_name": playlist.name])
            errorMessage = nil
        }
        catch { errorMessage = "No se pudo reordenar la playlist." }
    }

    private func delete(_ playlist: LocalPlaylist) {
        do {
            try library.delete(playlist)
            TelemetryLogger.shared.recordEvent(type: "playlist_delete", data: ["playlist_name": playlist.name])
            errorMessage = nil
        }
        catch { errorMessage = "No se pudo eliminar la playlist." }
    }
}
