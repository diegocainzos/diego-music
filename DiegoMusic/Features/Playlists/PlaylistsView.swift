import SwiftUI

struct CreatePlaylistSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
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
                            .dondaLabel()
                            .foregroundStyle(DiegoTheme.textSecondary)
                    }
                }
            }
            .tint(DiegoTheme.textPrimary)
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
            environment.createPlaylistInBackend(name: trimmed, description: descriptionText.isEmpty ? nil : descriptionText)
            onCreate?(newPlaylist)
            dismiss()
        } catch {
            errorMessage = "No se pudo crear la playlist."
        }
    }
}

struct PlaylistsView: View {
    @EnvironmentObject private var environment: AppEnvironment
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
                Text("PLAYLISTS")
                    .dondaTitle(size: 20)
                    .foregroundStyle(DiegoTheme.textPrimary)
                Spacer()
                Button {
                    isShowingCreateSheet = true
                } label: {
                    Text("CREAR")
                        .dondaLabel()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    isShowingImportSheet = true
                } label: {
                    Text("IMPORTAR")
                        .dondaLabel()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            HStack {
                TextField("Nombre de la nueva playlist", text: $newName)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 40)
                    .background(DiegoTheme.background)
                    .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                    .onSubmit(createPlaylist)
                Button(action: createPlaylist) {
                    Text("CREAR")
                        .dondaLabel()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textSecondary)
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
                                            .foregroundStyle(DiegoTheme.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        HStack {
                                            Button {
                                                downloadPlaylist(playlist)
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "arrow.down.circle")
                                                    Text("DESCARGAR PLAYLIST")
                                                        .dondaLabel()
                                                }
                                            }
                                            .buttonStyle(PrimaryButtonStyle())
                                            Spacer()
                                        }
                                        .padding(.bottom, 4)
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
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(entry.title)
                                                        .font(.system(size: 14, weight: .regular))
                                                        .foregroundStyle(DiegoTheme.textPrimary)
                                                        .lineLimit(1)
                                                    Text(entry.channelTitle)
                                                        .dondaLabel()
                                                        .foregroundStyle(DiegoTheme.textSecondary)
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
                                    Rectangle()
                                        .fill(DiegoTheme.surface)
                                        .frame(width: 44, height: 44)
                                        .overlay(Rectangle().stroke(DiegoTheme.hairline, lineWidth: 1))
                                        .overlay {
                                            Image(systemName: "music.note.list")
                                                .font(.callout)
                                                .foregroundStyle(DiegoTheme.textPrimary)
                                        }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundStyle(DiegoTheme.textPrimary)
                                        Text("\(playlist.entries.count) ELEMENTOS")
                                            .dondaLabel()
                                            .foregroundStyle(DiegoTheme.textSecondary)
                                    }
                                    Spacer()
                                    Button {
                                        downloadPlaylist(playlist)
                                    } label: {
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(DiegoTheme.textPrimary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Descargar playlist")
                                    .disabled(playlist.entries.isEmpty)

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
            environment.createPlaylistInBackend(name: name)
            newName = ""
            errorMessage = nil
        } catch {
            errorMessage = "No se pudo crear la playlist."
        }
    }

    private func remove(_ entry: PlaylistEntry, from playlist: LocalPlaylist) {
        do {
            try library.remove(entry, from: playlist)
            errorMessage = nil
        }
        catch { errorMessage = "No se pudo eliminar el elemento." }
    }

    private func move(_ entry: PlaylistEntry, in playlist: LocalPlaylist, by offset: Int) {
        do {
            try library.move(entry, in: playlist, by: offset)
            errorMessage = nil
        }
        catch { errorMessage = "No se pudo reordenar la playlist." }
    }

    private func delete(_ playlist: LocalPlaylist) {
        do {
            try library.delete(playlist)
            errorMessage = nil
        }
        catch { errorMessage = "No se pudo eliminar la playlist." }
    }

    private func downloadPlaylist(_ playlist: LocalPlaylist) {
        let items = playlist.entries.sorted(by: { $0.position < $1.position }).map(\.mediaItem)
        guard !items.isEmpty else { return }
        environment.downloadManager.enqueueBatch(items, resolver: environment.player.resolver)
    }
}
