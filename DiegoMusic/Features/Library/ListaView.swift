import SwiftUI

/// Listas de reproducción locales: crear, renombrar, borrar y reordenar
/// elementos (la gestión completa vive aquí; reutiliza `LibraryStore`).
struct ListaView: View {
    @ObservedObject var library: LibraryStore
    let query: String
    let onPlay: (MediaItem) -> Void
    var onPlayQueue: (([MediaItem], Int) -> Void)? = nil
    var youtubeService: (any YouTubeDataServicing)? = nil

    @State private var newName = ""
    @State private var expandedPlaylists: Set<UUID> = []
    @State private var renamingPlaylist: LocalPlaylist?
    @State private var isShowingCreateSheet = false
    @State private var isShowingImportSheet = false
    @State private var draftName = ""
    @State private var errorMessage: String?

    private var playlists: [LocalPlaylist] {
        library.playlists.filter { playlist in
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            return playlist.name.matches(query: query) || playlist.entries.contains { $0.title.matches(query: query) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            createRow

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textSecondary)
                    .accessibilityLabel(errorMessage)
            }

            Group {
                if playlists.isEmpty {
                    emptyState
                } else {
                    playlistsList
                }
            }
        }
        .sheet(item: $renamingPlaylist) { playlist in
            renameSheet(playlist)
        }
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

    private var createRow: some View {
        HStack(spacing: 10) {
            TextField("Nombre de la nueva playlist", text: $newName)
                .padding(.horizontal, 10)
                .frame(minHeight: 40)
                .background(DiegoTheme.background)
                .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                .onSubmit(createPlaylist)
                .accessibilityLabel("Nombre de la nueva playlist")

            Button(action: createPlaylist) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(DiegoTheme.textPrimary)
                    .foregroundStyle(DiegoTheme.background)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Crear playlist")

            Button {
                isShowingCreateSheet = true
            } label: {
                Text("NUEVA PLAYLIST")
                    .dondaLabel()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                isShowingImportSheet = true
            } label: {
                Text("IMPORTAR YOUTUBE")
                    .dondaLabel()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    @ViewBuilder private var emptyState: some View {
        EmptyStateView(
            title: "Sin listas",
            symbol: "music.note.list",
            description: "Crea una playlist para agrupar tus canciones."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var playlistsList: some View {
        List {
            ForEach(playlists) { playlist in
                DisclosureGroup(isExpanded: expandedBinding(for: playlist.id)) {
                    entriesSection(for: playlist)
                } label: {
                    playlistRow(playlist)
                }
                .tint(DiegoTheme.textPrimary)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func entriesSection(for playlist: LocalPlaylist) -> some View {
        let sortedEntries = playlist.entries.sorted(by: { $0.position < $1.position })
        return ForEach(
            Array(sortedEntries.enumerated()),
            id: \.element.id
        ) { index, entry in
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reproducir \(entry.title)")

                Button { move(entry, in: playlist, by: -1) } label: {
                    Image(systemName: "arrow.up").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .accessibilityLabel("Subir elemento")

                Button { move(entry, in: playlist, by: 1) } label: {
                    Image(systemName: "arrow.down").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(index == playlist.entries.count - 1)
                .accessibilityLabel("Bajar elemento")

                Button { remove(entry, from: playlist) } label: {
                    Image(systemName: "trash").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eliminar de la playlist")
            }
            .padding(.vertical, 4)
        }
    }

    private func playlistRow(_ playlist: LocalPlaylist) -> some View {
        HStack {
            Rectangle()
                .fill(DiegoTheme.surface)
                .frame(width: 44, height: 44)
                .overlay(Rectangle().stroke(DiegoTheme.hairline, lineWidth: 1))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.callout)
                        .foregroundStyle(DiegoTheme.textPrimary)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(DiegoTheme.textPrimary)
                Text("\(playlist.entries.count) ELEMENTOS")
                    .dondaLabel()
                    .foregroundStyle(DiegoTheme.textSecondary)
            }
            Spacer()
            Button { beginRename(playlist) } label: {
                Image(systemName: "pencil").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Renombrar playlist")
            Button { delete(playlist) } label: {
                Image(systemName: "trash").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Eliminar playlist")
        }
        .padding(.vertical, 4)
    }

    private func renameSheet(_ playlist: LocalPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RENOMBRAR PLAYLIST")
                .dondaTitle(size: 18)
                .foregroundStyle(DiegoTheme.textPrimary)
            TextField("Nombre de la playlist", text: $draftName)
                .padding(.horizontal, 10)
                .frame(minHeight: 40)
                .background(DiegoTheme.background)
                .overlay(Rectangle().stroke(DiegoTheme.outline, lineWidth: 1))
                .accessibilityLabel("Nuevo nombre de la playlist")
            HStack {
                Button { renamingPlaylist = nil } label: {
                    Text("CANCELAR").dondaLabel()
                }
                .buttonStyle(PrimaryButtonStyle())
                Spacer()
                Button {
                    do {
                        try library.rename(playlist, to: draftName)
                        errorMessage = nil
                    } catch {
                        errorMessage = "No se pudo renombrar la playlist."
                    }
                    renamingPlaylist = nil
                } label: {
                    Text("GUARDAR").dondaLabel()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DiegoTheme.background)
        .onAppear { draftName = playlist.name }
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
            newName = ""
            errorMessage = nil
        } catch {
            errorMessage = "No se pudo crear la playlist."
        }
    }

    private func beginRename(_ playlist: LocalPlaylist) {
        draftName = playlist.name
        renamingPlaylist = playlist
    }

    private func remove(_ entry: PlaylistEntry, from playlist: LocalPlaylist) {
        do { try library.remove(entry, from: playlist); errorMessage = nil }
        catch { errorMessage = "No se pudo eliminar el elemento." }
    }

    private func move(_ entry: PlaylistEntry, in playlist: LocalPlaylist, by offset: Int) {
        do { try library.move(entry, in: playlist, by: offset); errorMessage = nil }
        catch { errorMessage = "No se pudo reordenar la playlist." }
    }

    private func delete(_ playlist: LocalPlaylist) {
        do { try library.delete(playlist); errorMessage = nil }
        catch { errorMessage = "No se pudo eliminar la playlist." }
    }
}
