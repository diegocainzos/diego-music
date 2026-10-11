package com.diegocainzos.diegomusic.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.QueueMusic
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.DownloadDone
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.DownloadForOffline
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.LocalPlaylist
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.SavedTrack
import com.diegocainzos.diegomusic.core.formatBytes
import com.diegocainzos.diegomusic.data.DownloadState
import com.diegocainzos.diegomusic.ui.theme.DChip
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.EmptyState
import com.diegocainzos.diegomusic.ui.theme.Hairline
import com.diegocainzos.diegomusic.ui.theme.IconTap
import com.diegocainzos.diegomusic.ui.theme.PrimaryButton
import com.diegocainzos.diegomusic.ui.theme.Square
import com.diegocainzos.diegomusic.ui.theme.TrackArtwork
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.minimalCard
import com.diegocainzos.diegomusic.ui.theme.plainClickable
import kotlinx.coroutines.launch

enum class LibrarySegment(val title: String) {
    PLAYLISTS("Playlists"), PODCASTS("Podcasts"), SONGS("Canciones"), ALBUMS("Álbumes"), ARTISTS("Artistas"), DOWNLOADS("Descargas")
}

/** Segmento recordado durante la sesión (equivale a `@SceneStorage`). */
private var lastSegment = LibrarySegment.PLAYLISTS

@Composable
fun LibraryScreen() {
    val app = LocalApp.current
    var segment by rememberSaveable { mutableStateOf(lastSegment) }
    var showSettings by remember { mutableStateOf(false) }
    val toast = rememberToast()

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 12.dp)) {
                DTitle("Biblioteca", 14.sp, tracking = 6.sp, modifier = Modifier.align(Alignment.Center))
                IconTap(Icons.Default.Settings, "Ajustes", Modifier.align(Alignment.CenterEnd), size = 44.dp) { showSettings = true }
            }
            LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(LibrarySegment.entries) { s ->
                    DChip(s.title, segment == s) {
                        segment = s
                        lastSegment = s
                    }
                }
            }
            Box(Modifier.weight(1f).fillMaxWidth()) {
                when (segment) {
                    LibrarySegment.PLAYLISTS -> PlaylistsSection(toast)
                    LibrarySegment.PODCASTS -> PodcastsSection()
                    LibrarySegment.SONGS -> SongsSection(toast)
                    LibrarySegment.ALBUMS -> AlbumsSection()
                    LibrarySegment.ARTISTS -> ArtistsSection()
                    LibrarySegment.DOWNLOADS -> DownloadsSection()
                }
            }
        }
        toast.Host(this)
    }
    if (showSettings) SettingsSheet { showSettings = false }
}

// MARK: - Playlists

@Composable
private fun PlaylistsSection(toast: ToastState) {
    val app = LocalApp.current
    val c = Donda.colors
    val playlists by app.library.playlists.collectAsState()
    var newName by remember { mutableStateOf("") }
    var expanded by remember { mutableStateOf(setOf<String>()) }
    var showCreate by remember { mutableStateOf(false) }
    var showImport by remember { mutableStateOf(false) }
    var renaming by remember { mutableStateOf<LocalPlaylist?>(null) }

    fun create() {
        val name = newName.trim()
        if (name.isEmpty()) return
        app.library.createPlaylist(name)
        newName = ""
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 16.dp + LocalBottomInset.current),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DTitle("Playlists", 20.sp, modifier = Modifier.weight(1f))
                PrimaryButton("Crear") { showCreate = true }
                PrimaryButton("Importar") { showImport = true }
            }
        }
        item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DField(newName, { newName = it }, "Nombre de la nueva playlist", Modifier.weight(1f), onSubmit = ::create)
                PrimaryButton("Crear", onClick = ::create)
            }
        }
        if (playlists.isEmpty()) {
            item { EmptyState("Sin playlists", Icons.AutoMirrored.Filled.QueueMusic, "Crea una mezcla local para empezar.", Modifier.fillMaxWidth()) }
        }
        items(playlists, key = { it.id }) { playlist ->
            val isOpen = playlist.id in expanded
            val entries = playlist.entries.sortedBy { it.position }
            Column(Modifier.fillMaxWidth().minimalCard(c)) {
                Row(
                    Modifier.fillMaxWidth().plainClickable { expanded = if (isOpen) expanded - playlist.id else expanded + playlist.id },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.size(44.dp).hairlineBorder(c.hairline), contentAlignment = Alignment.Center) {
                        Icon(Icons.AutoMirrored.Filled.QueueMusic, null, tint = c.textPrimary, modifier = Modifier.size(18.dp))
                    }
                    Column(Modifier.weight(1f).padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        DText(playlist.name, size = 15.sp, maxLines = 1)
                        DLabel("${playlist.entries.size} elementos")
                    }
                    IconTap(Icons.Outlined.DownloadForOffline, "Descargar playlist", iconSize = 18.dp, enabled = entries.isNotEmpty()) {
                        app.downloads.enqueueBatch(entries.map { it.mediaItem }, app.resolver)
                    }
                    IconTap(Icons.Default.Edit, "Renombrar playlist", iconSize = 16.dp) { renaming = playlist }
                    DeleteTap("Eliminar playlist") { app.library.delete(playlist) }
                    Icon(if (isOpen) Icons.Default.ExpandLess else Icons.Default.ExpandMore, null, tint = c.textPrimary, modifier = Modifier.size(18.dp))
                }
                if (isOpen) {
                    Column(Modifier.padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (entries.isEmpty()) {
                            DText("Añade elementos desde Búsqueda.", size = 15.sp, color = c.textSecondary)
                        } else {
                            PrimaryButton("Descargar playlist", icon = Icons.Default.Download) {
                                app.downloads.enqueueBatch(entries.map { it.mediaItem }, app.resolver)
                            }
                        }
                        entries.forEachIndexed { index, entry ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f).plainClickable { app.playQueue(entries.map { it.mediaItem }, index) }, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    DText(entry.title, maxLines = 1)
                                    DLabel(entry.channelTitle, maxLines = 1)
                                }
                                IconTap(Icons.Default.ArrowUpward, "Subir elemento", enabled = index > 0, tint = if (index > 0) c.textPrimary else c.textSecondary) {
                                    app.library.move(entry, playlist, -1)
                                }
                                IconTap(Icons.Default.ArrowDownward, "Bajar elemento", enabled = index < entries.size - 1, tint = if (index < entries.size - 1) c.textPrimary else c.textSecondary) {
                                    app.library.move(entry, playlist, 1)
                                }
                                DeleteTap("Eliminar de la playlist") { app.library.remove(entry, playlist) }
                            }
                        }
                        androidx.compose.runtime.LaunchedEffect(playlist.id) { app.player.warm(entries.map { it.mediaItem }) }
                    }
                }
            }
        }
    }

    if (showCreate) CreatePlaylistSheet(onCreated = { expanded = expanded + it.id }) { showCreate = false }
    if (showImport) ImportPlaylistSheet(onImported = { expanded = expanded + it.id; toast.show("Playlist importada") }) { showImport = false }
    renaming?.let { p -> RenamePlaylistSheet(p) { renaming = null } }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DondaSheet(onDismiss: () -> Unit, content: @Composable () -> Unit) {
    val c = Donda.colors
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = Square,
        containerColor = c.background,
        contentColor = c.textPrimary,
        dragHandle = null,
        tonalElevation = 0.dp,
    ) { content() }
}

@Composable
private fun SheetForm(title: String, onCancel: () -> Unit, confirm: String, confirmEnabled: Boolean, onConfirm: () -> Unit, content: @Composable () -> Unit) {
    val c = Donda.colors
    Column(Modifier.fillMaxWidth().padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            DLabel("Cancelar", color = c.textPrimary, modifier = Modifier.plainClickable(onClick = onCancel))
            DTitle(title, 16.sp, modifier = Modifier.weight(1f), align = TextAlign.Center)
            DLabel(confirm, color = if (confirmEnabled) c.textPrimary else c.textSecondary, modifier = Modifier.plainClickable(enabled = confirmEnabled, onClick = onConfirm))
        }
        content()
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun CreatePlaylistSheet(onCreated: (LocalPlaylist) -> Unit, onDismiss: () -> Unit) {
    val app = LocalApp.current
    var name by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    DondaSheet(onDismiss) {
        SheetForm("Nueva playlist", onDismiss, "Crear", name.isNotBlank(), {
            onCreated(app.library.createPlaylist(name.trim()))
            onDismiss()
        }) {
            DLabel("Detalles de la playlist")
            DField(name, { name = it }, "Nombre de la playlist")
            DField(description, { description = it }, "Descripción (opcional)")
        }
    }
}

@Composable
private fun RenamePlaylistSheet(playlist: LocalPlaylist, onDismiss: () -> Unit) {
    val app = LocalApp.current
    var name by remember { mutableStateOf(playlist.name) }
    DondaSheet(onDismiss) {
        SheetForm("Renombrar playlist", onDismiss, "Guardar", name.isNotBlank(), {
            app.library.rename(playlist, name)
            onDismiss()
        }) { DField(name, { name = it }, "Nombre de la playlist") }
    }
}

/** Importa una playlist de YouTube por enlace o ID. */
@Composable
private fun ImportPlaylistSheet(onImported: (LocalPlaylist) -> Unit, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val c = Donda.colors
    val scope = rememberCoroutineScope()
    var input by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    DondaSheet(onDismiss) {
        SheetForm("Importar playlist", onDismiss, "Importar", input.isNotBlank() && !loading, {
            val id = extractPlaylistId(input.trim())
            if (id == null) {
                error = "No se pudo extraer el ID de playlist. Revisa el enlace."
                return@SheetForm
            }
            loading = true
            error = null
            scope.launch {
                try {
                    val album = app.youtube.album(id)
                    if (album.tracks.isEmpty()) {
                        error = "La playlist de YouTube está vacía o es privada."
                    } else {
                        val created = app.library.createPlaylist(album.title)
                        album.tracks.forEach { app.library.add(it, created) }
                        onImported(created)
                        onDismiss()
                    }
                } catch (_: Exception) {
                    error = "Error al importar la playlist de YouTube."
                }
                loading = false
            }
        }) {
            DLabel("Importar desde YouTube")
            DField(input, { input = it }, "Enlace o ID de playlist de YouTube", keyboardType = androidx.compose.ui.text.input.KeyboardType.Uri)
            DText("Ejemplo: https://www.youtube.com/playlist?list=PL... o ID directo 'PL...'", size = 12.sp, color = c.textSecondary)
            if (loading) LoadingLabel("Obteniendo canciones de YouTube...")
            error?.let { DLabel(it) }
        }
    }
}

fun extractPlaylistId(input: String): String? {
    if ("list=" in input) return Regex("(?<=list=)[A-Za-z0-9_-]+").find(input)?.value
    return input.takeIf { "/" !in it && "?" !in it && it.isNotEmpty() }
}

// MARK: - Podcasts

@Composable
private fun PodcastsSection() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val shows by app.library.followedShows.collectAsState()
    if (shows.isEmpty()) {
        DLabel(
            "No sigues ningún podcast. Búscalo y pulsa seguir.",
            Modifier.fillMaxSize().padding(horizontal = 32.dp, vertical = 80.dp), align = TextAlign.Center,
        )
        return
    }
    LazyColumn(contentPadding = PaddingValues(16.dp, 16.dp, 16.dp, 16.dp + LocalBottomInset.current), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        items(shows, key = { it.channelId }) { show ->
            Row(
                Modifier.fillMaxWidth().plainClickable { nav.navigate(Destination.PodcastDetail(show.channelId, show.title)) },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TrackArtwork(show.thumbnailUrl, Modifier.size(52.dp))
                DLabel(show.title, color = Donda.colors.textPrimary, maxLines = 2, modifier = Modifier.padding(start = 14.dp))
            }
        }
    }
}

// MARK: - Canciones

@Composable
private fun SongsSection(toast: ToastState) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val c = Donda.colors
    val favorites by app.library.favorites.collectAsState()
    val states by app.downloads.states.collectAsState()
    val connected by app.network.isConnected.collectAsState()
    var onlyDownloaded by rememberSaveable { mutableStateOf(false) }
    val filtered: List<SavedTrack> = if (onlyDownloaded) favorites.filter { states[it.videoId] == DownloadState.Downloaded } else favorites

    if (filtered.isEmpty() && !onlyDownloaded) {
        EmptyState("Sin canciones", Icons.Default.MusicNote, "Guarda canciones desde Búsqueda para verlas aquí.", Modifier.fillMaxSize())
        return
    }
    LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 12.dp + LocalBottomInset.current), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        item {
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp).padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.DownloadDone, null, tint = c.textPrimary, modifier = Modifier.size(14.dp))
                DLabel("Solo descargados", color = c.textPrimary, modifier = Modifier.weight(1f).padding(start = 8.dp))
                Switch(
                    checked = onlyDownloaded, onCheckedChange = { onlyDownloaded = it },
                    colors = SwitchDefaults.colors(
                        checkedTrackColor = c.textPrimary, checkedThumbColor = c.background,
                        uncheckedTrackColor = c.background, uncheckedThumbColor = c.textSecondary, uncheckedBorderColor = c.outline,
                    ),
                )
            }
        }
        item {
            Row(Modifier.padding(horizontal = 8.dp).padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                DLabel("#", modifier = Modifier.width(28.dp), align = TextAlign.Center)
                DLabel("Título", modifier = Modifier.weight(1f))
                DLabel("Artista", modifier = Modifier.weight(1f))
            }
            Hairline(Modifier.padding(bottom = 8.dp))
        }
        if (filtered.isEmpty()) {
            item { EmptyState("Sin descargas", Icons.Default.Download, "Descarga canciones para escucharlas sin conexión.", Modifier.fillMaxWidth()) }
        }
        itemsIndexed(filtered, key = { _, t -> t.videoId }) { index, track ->
            val unavailable = !connected && states[track.videoId] != DownloadState.Downloaded
            Row(
                Modifier.fillMaxWidth().hairlineBorder(c.hairline).padding(horizontal = 8.dp, vertical = 6.dp)
                    .then(if (unavailable) Modifier.background(c.background.copy(alpha = 0.6f)) else Modifier),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    Modifier.weight(1f).plainClickable(enabled = !unavailable) { app.playQueue(filtered.map { it.mediaItem }, index) },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    DLabel("${index + 1}", modifier = Modifier.width(28.dp), align = TextAlign.Center)
                    TrackArtwork(track.thumbnailUrl, Modifier.size(40.dp))
                    DText(track.title, maxLines = 1, color = if (unavailable) c.textSecondary else c.textPrimary, modifier = Modifier.weight(1f))
                    DLabel(
                        track.channelTitle, maxLines = 1,
                        modifier = Modifier.weight(1f).plainClickable { nav.navigate(Destination.ArtistDetail(track.channelTitle, track.channelTitle)) },
                    )
                }
                DownloadButton(track.mediaItem)
                FavoriteButton(track.mediaItem)
                TrackMenuButton(track.mediaItem, toast, showAlbum = false)
            }
        }
    }
}

// MARK: - Álbumes

@Composable
private fun AlbumsSection() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val saved by app.library.savedAlbums.collectAsState()
    val favorites by app.library.favorites.collectAsState()
    val history by app.library.history.collectAsState()
    val local = remember(favorites, history) { app.library.artists }
    if (saved.isEmpty() && local.isEmpty()) {
        EmptyState("Sin álbumes", Icons.Default.LibraryMusic, "Guarda álbumes desde el reproductor o la ficha del álbum para tenerlos aquí.", Modifier.fillMaxSize())
        return
    }
    LazyColumn(contentPadding = PaddingValues(16.dp, 16.dp, 16.dp, 16.dp + LocalBottomInset.current), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        if (saved.isNotEmpty()) {
            item { DLabel("Álbumes guardados", tracking = 4.sp) }
            items(saved.chunked(2)) { pair ->
                GridRow(pair.size) { i ->
                    val album = pair[i]
                    AlbumCard(
                        album.thumbnailUrl, album.title, album.channelTitle,
                        onOpen = { nav.navigate(Destination.AlbumDetail(album.id, album.title)) },
                        onPlay = { app.play(MediaItem(album.id, album.title, album.channelTitle ?: "Álbum", album.thumbnailUrl)) },
                        onDelete = { app.library.deleteSavedAlbum(album.id) },
                    )
                }
            }
        }
        if (local.isNotEmpty()) {
            if (saved.isNotEmpty()) item { DLabel("Agrupaciones locales", tracking = 4.sp) }
            items(local.chunked(2)) { pair ->
                GridRow(pair.size) { i ->
                    val album = pair[i]
                    AlbumCard(
                        album.tracks.firstOrNull()?.thumbnailUrl, album.name, "${album.tracks.size} canciones",
                        onOpen = { nav.navigate(Destination.AlbumDetail(album.name, album.name)) },
                        onPlay = { album.tracks.firstOrNull()?.let { app.play(it.mediaItem) } },
                    )
                }
            }
        }
    }
}

@Composable
private fun GridRow(count: Int, cell: @Composable (Int) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
        repeat(2) { i -> Box(Modifier.weight(1f)) { if (i < count) cell(i) } }
    }
}

@Composable
private fun AlbumCard(art: String?, title: String, subtitle: String?, onOpen: () -> Unit, onPlay: () -> Unit, onDelete: (() -> Unit)? = null) {
    val c = Donda.colors
    var menu by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.fillMaxWidth().aspectRatio(1f)) {
            TrackArtwork(art, Modifier.fillMaxSize().plainClickable(onClick = onOpen))
            Box(
                Modifier.align(Alignment.BottomEnd).padding(8.dp).size(32.dp).background(c.background).hairlineBorder(c.outline).plainClickable(onClick = onPlay),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.PlayArrow, "Reproducir", tint = c.textPrimary, modifier = Modifier.size(14.dp)) }
        }
        Box {
            Column(Modifier.fillMaxWidth().plainClickable { if (onDelete != null) menu = true else onOpen() }, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                DText(title, maxLines = 1)
                subtitle?.let { DLabel(it, maxLines = 1) }
            }
            if (onDelete != null) {
                DondaMenu(menu, { menu = false }) {
                    DondaMenuItem("Abrir") { menu = false; onOpen() }
                    DondaMenuItem("Eliminar de la biblioteca") { menu = false; onDelete() }
                }
            }
        }
    }
}

// MARK: - Artistas

@Composable
private fun ArtistsSection() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val c = Donda.colors
    val favorites by app.library.favorites.collectAsState()
    val history by app.library.history.collectAsState()
    val artists = remember(favorites, history) { app.library.artists }
    if (artists.isEmpty()) {
        EmptyState("Sin artistas en la biblioteca", Icons.Default.Mic, "Guarda o reproduce canciones para organizarlas por artista automáticamente.", Modifier.fillMaxSize())
        return
    }
    LazyColumn(contentPadding = PaddingValues(16.dp, 8.dp, 16.dp, 16.dp + LocalBottomInset.current), verticalArrangement = Arrangement.spacedBy(28.dp)) {
        item { DLabel("Artistas guardados", tracking = 4.sp, modifier = Modifier.padding(top = 8.dp)) }
        items(artists.chunked(2)) { pair ->
            GridRow(pair.size) { i ->
                val artist = pair[i]
                Column(
                    Modifier.fillMaxWidth().hairlineBorder(c.hairline).plainClickable { nav.navigate(Destination.ArtistDetail(artist.name, artist.name)) }.padding(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(Modifier.fillMaxWidth().aspectRatio(1f)) {
                        TrackArtwork(artist.tracks.firstOrNull()?.thumbnailUrl, Modifier.fillMaxSize())
                        Box(
                            Modifier.align(Alignment.BottomEnd).padding(4.dp).size(32.dp).background(c.background).hairlineBorder(c.outline)
                                .plainClickable { artist.tracks.firstOrNull()?.let { app.play(it.mediaItem) } },
                            contentAlignment = Alignment.Center,
                        ) { Icon(Icons.Default.PlayArrow, "Reproducir canciones de ${artist.name}", tint = c.textPrimary, modifier = Modifier.size(14.dp)) }
                    }
                    DText(artist.name, maxLines = 1, align = TextAlign.Center)
                    DLabel(if (artist.tracks.size == 1) "1 canción" else "${artist.tracks.size} canciones")
                }
            }
        }
    }
}

// MARK: - Descargas

@Composable
private fun DownloadsSection() {
    val app = LocalApp.current
    val c = Donda.colors
    val downloaded by app.downloads.downloadedTracks.collectAsState()
    var deleting by remember { mutableStateOf<String?>(null) }
    if (downloaded.isEmpty()) {
        EmptyState(
            "Sin descargas", Icons.Default.Download,
            "Las canciones, álbumes y playlists que descargues aparecerán aquí para escucharlas sin conexión.",
            Modifier.fillMaxSize().padding(top = 60.dp),
        )
        return
    }
    LazyColumn(contentPadding = PaddingValues(bottom = 120.dp)) {
        items(downloaded, key = { it.videoId }) { track ->
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f).plainClickable { app.play(track.mediaItem) }, verticalAlignment = Alignment.CenterVertically) {
                    TrackArtwork(track.thumbnailUrl, Modifier.size(44.dp))
                    Column(Modifier.padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        DText(track.title, maxLines = 1)
                        DLabel("${track.channelTitle} · ${formatBytes(track.fileSizeBytes)}", maxLines = 1)
                    }
                }
                IconTap(Icons.Default.DownloadDone, "Eliminar descarga de ${track.title}", iconSize = 18.dp) { deleting = track.videoId }
            }
            Hairline(Modifier.padding(start = 72.dp))
        }
    }
    deleting?.let { id ->
        val title = downloaded.firstOrNull { it.videoId == id }?.title.orEmpty()
        ConfirmDialog("Eliminar descarga", "Se borrará \"$title\" del almacenamiento local.", "Eliminar", { app.downloads.removeDownload(id) }) { deleting = null }
    }
}
