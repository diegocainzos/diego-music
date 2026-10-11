package com.diegocainzos.diegomusic.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.PlaylistAdd
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DownloadDone
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.data.DownloadState
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DToast
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.IconTap
import com.diegocainzos.diegomusic.ui.theme.Square
import com.diegocainzos.diegomusic.ui.theme.TrackArtwork
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.plainClickable
import kotlinx.coroutines.delay

/** Alto que deja libre el mini‑player flotante al final de cada lista. */
val LocalBottomInset = compositionLocalOf { 0.dp }

@Composable
fun BottomInsetSpacer(extra: Dp = 0.dp) = Spacer(Modifier.height(LocalBottomInset.current + extra))

// MARK: - Toasts

class ToastState {
    var message by mutableStateOf<String?>(null)
    private var serial by mutableStateOf(0)
    fun show(text: String) {
        message = text
        serial++
    }

    @Composable
    fun Host(scope: BoxScope, inverted: Boolean = true, durationMillis: Long = 2_000) = with(scope) {
        LaunchedEffect(serial) {
            if (message != null) {
                delay(durationMillis)
                message = null
            }
        }
        AnimatedVisibility(
            visible = message != null,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp + LocalBottomInset.current),
        ) {
            DToast(message.orEmpty(), inverted)
        }
    }
}

@Composable
fun rememberToast() = remember { ToastState() }

// MARK: - Barra superior con «ATRÁS»

@Composable
fun BackBar(label: String) {
    val nav = LocalNav.current
    val c = Donda.colors
    Box(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 6.dp)) {
        if (nav.canGoBack) {
            Row(
                Modifier.align(Alignment.CenterStart).hairlineBorder(c.outline).plainClickable { nav.goBack() }
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.ChevronLeft, "Volver atrás", tint = c.textPrimary, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                DLabel("Atrás", color = c.textPrimary)
            }
        }
        if (label.isNotEmpty()) DLabel(label, Modifier.align(Alignment.Center))
    }
}

// MARK: - Menú de pista («…»)

/** Menú contextual Donda: rectangular, fondo `background`, borde `outline`. */
@Composable
fun DondaMenu(expanded: Boolean, onDismiss: () -> Unit, content: @Composable () -> Unit) {
    val c = Donda.colors
    DropdownMenu(
        expanded = expanded,
        onDismissRequest = onDismiss,
        shape = Square,
        containerColor = c.background,
        border = androidx.compose.foundation.BorderStroke(1.dp, c.outline),
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
    ) { content() }
}

@Composable
fun DondaMenuItem(text: String, icon: ImageVector? = null, onClick: () -> Unit) {
    val c = Donda.colors
    DropdownMenuItem(
        text = { DText(text, size = 15.sp) },
        leadingIcon = icon?.let { { Icon(it, null, tint = c.textPrimary, modifier = Modifier.size(18.dp)) } },
        onClick = onClick,
    )
}

/** Lista de playlists dentro de un menú, como el submenú «Añadir a playlist» de Swift. */
@Composable
fun AddToPlaylistItems(item: MediaItem, onDone: () -> Unit) {
    val app = LocalApp.current
    val playlists by app.library.playlists.collectAsState()
    if (playlists.isEmpty()) return
    var open by remember { mutableStateOf(false) }
    DondaMenuItem("Añadir a playlist", Icons.AutoMirrored.Filled.PlaylistAdd) { open = !open }
    if (open) {
        playlists.forEach { p ->
            DropdownMenuItem(
                text = { DLabel("— ${p.name}", color = Donda.colors.textPrimary) },
                onClick = {
                    app.library.add(item, p)
                    onDone()
                },
            )
        }
    }
}

/** Botón «…» con las acciones habituales de una pista. */
@Composable
fun TrackMenuButton(
    item: MediaItem,
    toast: ToastState?,
    showArtist: Boolean = true,
    showAlbum: Boolean = true,
    extra: (@Composable (close: () -> Unit) -> Unit)? = null,
) {
    val app = LocalApp.current
    val nav = LocalNav.current
    var open by remember { mutableStateOf(false) }
    Box {
        IconTap(Icons.Default.MoreHoriz, "Más opciones para ${item.title}", tint = Donda.colors.textSecondary, iconSize = 18.dp) { open = true }
        DondaMenu(open, { open = false }) {
            extra?.invoke { open = false }
            DondaMenuItem("Añadir a la cola") {
                app.queue.enqueueNext(item)
                toast?.show("Añadida a continuación")
                open = false
            }
            if (showArtist) {
                DondaMenuItem("Ir al artista (${item.channelTitle})") {
                    open = false
                    nav.navigate(Destination.ArtistDetail(item.channelTitle, item.channelTitle))
                }
            }
            if (showAlbum) {
                DondaMenuItem("Ir al álbum") {
                    open = false
                    nav.navigate(Destination.AlbumDetail(item.title, item.title))
                }
            }
            AddToPlaylistItems(item) { open = false }
        }
    }
}

@Composable
fun FavoriteButton(item: MediaItem, size: Dp = 36.dp, iconSize: Dp = 16.dp) {
    val app = LocalApp.current
    val favorites by app.library.favorites.collectAsState()
    val isFavorite = favorites.any { it.videoId == item.id }
    val c = Donda.colors
    IconTap(
        if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
        if (isFavorite) "Quitar de favoritos" else "Añadir a favoritos",
        size = size,
        iconSize = iconSize,
        tint = if (isFavorite) c.textPrimary else c.textSecondary,
    ) { app.library.toggleFavorite(item) }
}

// MARK: - Descargas

@Composable
fun downloadState(videoId: String): DownloadState {
    val states by LocalApp.current.downloads.states.collectAsState()
    return states[videoId] ?: DownloadState.NotDownloaded
}

/** Botón de descarga de una pista: flecha → progreso → descargado (tocar para borrar). */
@Composable
fun DownloadButton(item: MediaItem) {
    val app = LocalApp.current
    val c = Donda.colors
    val state = downloadState(item.id)
    var confirmDelete by remember { mutableStateOf(false) }
    Box(
        Modifier.size(32.dp).plainClickable {
            when (state) {
                DownloadState.NotDownloaded, is DownloadState.Failed -> app.downloads.enqueue(item, app.resolver)
                DownloadState.Downloaded -> confirmDelete = true
                else -> Unit
            }
        },
        contentAlignment = Alignment.Center,
    ) {
        when (state) {
            DownloadState.NotDownloaded -> Icon(Icons.Default.ArrowDownward, "Descargar ${item.title}", tint = c.textSecondary, modifier = Modifier.size(16.dp))
            DownloadState.Queued -> Icon(Icons.Default.AccessTime, "En cola", tint = c.textSecondary, modifier = Modifier.size(16.dp))
            is DownloadState.Downloading -> Box(Modifier.size(16.dp).hairlineBorder(c.outline)) {
                Box(Modifier.fillMaxWidth(state.progress.toFloat().coerceAtLeast(0.12f)).height(16.dp).background(c.textPrimary))
            }
            DownloadState.Downloaded -> Icon(Icons.Default.DownloadDone, "Descargado", tint = c.textPrimary, modifier = Modifier.size(16.dp))
            is DownloadState.Failed -> Icon(Icons.Default.ErrorOutline, "Error al descargar", tint = c.textSecondary, modifier = Modifier.size(16.dp))
        }
    }
    if (confirmDelete) {
        ConfirmDialog(
            title = "Eliminar descarga",
            message = "Se borrará \"${item.title}\" del almacenamiento local.",
            confirm = "Eliminar",
            onConfirm = { app.downloads.removeDownload(item.id) },
            onDismiss = { confirmDelete = false },
        )
    }
}

/** Variante de episodio: porcentaje y check (detalle de podcast). */
@Composable
fun EpisodeDownloadButton(item: MediaItem, size: Dp = 36.dp) {
    val app = LocalApp.current
    val c = Donda.colors
    val state = downloadState(item.id)
    Box(
        Modifier.size(size).plainClickable {
            when (state) {
                DownloadState.Downloaded -> app.downloads.removeDownload(item.id)
                DownloadState.NotDownloaded, is DownloadState.Failed -> app.downloads.enqueue(item, app.resolver)
                else -> Unit
            }
        },
        contentAlignment = Alignment.Center,
    ) {
        when (state) {
            DownloadState.NotDownloaded, is DownloadState.Failed ->
                Icon(Icons.Default.ArrowDownward, "Descargar ${item.title}", tint = c.textSecondary, modifier = Modifier.size(16.dp))
            DownloadState.Queued -> DLabel("...")
            is DownloadState.Downloading -> DLabel("${(state.progress * 100).toInt()}%", color = c.textPrimary)
            DownloadState.Downloaded -> Icon(Icons.Default.Check, "Descargado. Tocar para eliminar", tint = c.textPrimary, modifier = Modifier.size(16.dp))
        }
    }
}

/** «DESCARGAR TODO» para álbumes y playlists. */
@Composable
fun DownloadAllButton(items: List<MediaItem>) {
    val app = LocalApp.current
    val c = Donda.colors
    val states by app.downloads.states.collectAsState()
    val downloaded = items.count { states[it.id] == DownloadState.Downloaded }
    val all = items.isNotEmpty() && downloaded == items.size
    val inProgress = items.any { states[it.id] == DownloadState.Queued || states[it.id] is DownloadState.Downloading }
    Row(
        Modifier.background(c.background).hairlineBorder(c.outline)
            .plainClickable(enabled = !all && !inProgress) { app.downloads.enqueueBatch(items, app.resolver) }
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when {
            inProgress -> {
                CircularProgressIndicator(Modifier.size(12.dp), color = c.textPrimary, strokeWidth = 1.5.dp)
                Spacer(Modifier.width(6.dp))
                DLabel("Descargando $downloaded/${items.size}")
            }
            all -> {
                Icon(Icons.Default.DownloadDone, null, tint = c.textPrimary, modifier = Modifier.size(13.dp))
                Spacer(Modifier.width(6.dp))
                DLabel("Descargado", color = c.textPrimary)
            }
            else -> {
                Icon(Icons.Default.ArrowDownward, null, tint = c.textPrimary, modifier = Modifier.size(13.dp))
                Spacer(Modifier.width(6.dp))
                DLabel("Descargar todo", color = c.textPrimary)
            }
        }
    }
}

@Composable
fun OfflineBanner() {
    val connected by LocalApp.current.network.isConnected.collectAsState()
    val c = Donda.colors
    AnimatedVisibility(!connected) {
        Row(
            Modifier.fillMaxWidth().background(c.background).hairlineBorder(c.hairline).padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.WifiOff, null, tint = c.textPrimary, modifier = Modifier.size(12.dp))
            Spacer(Modifier.width(8.dp))
            DLabel("Sin conexión — solo música descargada disponible", color = c.textPrimary, align = TextAlign.Center)
        }
    }
}

@Composable
fun ConfirmDialog(title: String, message: String, confirm: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    val c = Donda.colors
    AlertDialog(
        onDismissRequest = onDismiss,
        shape = Square,
        containerColor = c.background,
        modifier = Modifier.hairlineBorder(c.outline),
        title = { DLabel(title, color = c.textPrimary, size = 13.sp) },
        text = { DText(message, color = c.textSecondary) },
        confirmButton = {
            DLabel(confirm, color = c.textPrimary, modifier = Modifier.plainClickable { onConfirm(); onDismiss() }.padding(12.dp))
        },
        dismissButton = { DLabel("Cancelar", modifier = Modifier.plainClickable(onClick = onDismiss).padding(12.dp)) },
    )
}

// MARK: - Carrusel de tarjetas de 128 dp (Inicio)

@Composable
fun <T> CardCarousel(
    items: List<T>,
    key: (T) -> String,
    artwork: (T) -> String?,
    onClick: (T) -> Unit,
    title: @Composable (T) -> Unit,
) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        items(items, key = key) { item ->
            Column(Modifier.width(128.dp).plainClickable { onClick(item) }, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                TrackArtwork(artwork(item), Modifier.size(128.dp))
                title(item)
            }
        }
    }
}

@Composable
fun MediaCardTitle(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        DText(title, size = 13.sp, maxLines = 1)
        DLabel(subtitle, maxLines = 1)
    }
}

/** Indicador de carga Donda con etiqueta. */
@Composable
fun LoadingLabel(text: String, modifier: Modifier = Modifier) {
    val c = Donda.colors
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
        CircularProgressIndicator(Modifier.size(18.dp), color = c.textPrimary, strokeWidth = 1.5.dp)
        Spacer(Modifier.width(12.dp))
        DLabel(text)
    }
}

/** Botón de borrar con icono (playlists, descargas). */
@Composable
fun DeleteTap(description: String, onClick: () -> Unit) =
    IconTap(Icons.Default.Delete, description, size = 44.dp, iconSize = 18.dp, tint = Donda.colors.textPrimary, onClick = onClick)
