import SwiftUI

/// Listas de reproducción locales: crear, renombrar, borrar y reordenar
/// elementos (la gestión completa vive aquí; reutiliza `LibraryStore`).
struct ListaView: View {
    @ObservedObject var library: LibraryStore
    let query: String
    let onPlay: (MediaItem) -> Void

    @State private var newName = ""
    @State private var expandedPlaylists: Set<UUID> = []
    @State private var renamingPlaylist: LocalPlaylist?
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
                    .font(.caption)
                    .foregroundStyle(DiegoTheme.red)
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
    }

    private var createRow: some View {
        HStack(spacing: 10) {
            TextField("Nombre de la nueva playlist", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .onSubmit(createPlaylist)
                .accessibilityLabel("Nombre de la nueva playlist")
            Button(action: createPlaylist) {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
                    .background(DiegoTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Crear playlist")
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
                .tint(DiegoTheme.accent)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func entriesSection(for playlist: LocalPlaylist) -> some View {
        ForEach(
            Array(playlist.entries.sorted(by: { $0.position < $1.position }).enumerated()),
            id: \.element.id
        ) { index, entry in
            HStack(spacing: 10) {
                Button { onPlay(entry.mediaItem) } label: {
                    VStack(alignment: .leading) {
                        Text(entry.title).font(.headline).lineLimit(1)
                        Text(entry.channelTitle).font(.caption).foregroundStyle(.secondary)
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
            Circle()
                .fill(DiegoTheme.accent.opacity(0.85))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.callout)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(playlist.name).font(.title3.bold())
                Text("\(playlist.entries.count) elementos").font(.caption).foregroundStyle(.secondary)
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
            Text("Renombrar playlist").font(.title2.bold())
            TextField("Nombre de la playlist", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .accessibilityLabel("Nuevo nombre de la playlist")
            HStack {
                Button("Cancelar") { renamingPlaylist = nil }
                    .buttonStyle(PrimaryButtonStyle())
                Spacer()
                Button("Guardar") {
                    do {
                        try library.rename(playlist, to: draftName)
                        errorMessage = nil
                    } catch {
                        errorMessage = "No se pudo renombrar la playlist."
                    }
                    renamingPlaylist = nil
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
