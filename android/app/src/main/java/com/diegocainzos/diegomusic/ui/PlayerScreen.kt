package com.diegocainzos.diegomusic.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FastForward
import androidx.compose.material.icons.filled.FastRewind
import androidx.compose.material.icons.filled.FormatQuote
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.RepeatOne
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.RepeatMode as QueueRepeat
import com.diegocainzos.diegomusic.core.formatTime
import com.diegocainzos.diegomusic.data.DownloadState
import com.diegocainzos.diegomusic.data.PlaybackSettings
import com.diegocainzos.diegomusic.player.AudioPlaybackState
import com.diegocainzos.diegomusic.player.PlaybackContext
import com.diegocainzos.diegomusic.player.PlayerCoordinator
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.IconTap
import com.diegocainzos.diegomusic.ui.theme.OutlineButton
import com.diegocainzos.diegomusic.ui.theme.ProgressLine
import com.diegocainzos.diegomusic.ui.theme.TrackArtwork
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.plainClickable

// MARK: - Mini‑player

@Composable
fun MiniPlayer(onExpand: () -> Unit, modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val player = app.player
    val c = Donda.colors
    val queueState by app.queue.state.collectAsState()
    val current = queueState.current ?: return
    val state by player.playbackState.collectAsState()
    val time by player.currentTime.collectAsState()
    val duration by player.duration.collectAsState()
    val context by player.context.collectAsState()
    val error by player.errorMessage.collectAsState()
    val isPlaying = state == AudioPlaybackState.PLAYING
    val canAdvance = remember(queueState) { app.queue.canAdvance }

    Column(modifier.fillMaxWidth().background(c.background)) {
        Row(
            Modifier.fillMaxWidth().plainClickable(onClick = onExpand).padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TrackArtwork(current.artworkUrl, Modifier.size(42.dp))
            Column(Modifier.weight(1f).padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                DText(current.title.uppercase(), size = 13.sp, mono = true, maxLines = 1)
                DText(
                    if (state == AudioPlaybackState.FAILED && error != null) error!! else current.channelTitle,
                    size = 11.sp, mono = true, color = c.textSecondary, maxLines = 1,
                )
            }
            if (state == AudioPlaybackState.RESOLVING || state == AudioPlaybackState.BUFFERING) {
                Box(Modifier.size(36.dp).plainClickable { player.togglePlayback() }, contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(Modifier.size(16.dp), color = c.textPrimary, strokeWidth = 1.5.dp)
                }
            } else {
                IconTap(
                    if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                    if (isPlaying) "Pausar" else "Reproducir", iconSize = 22.dp,
                ) { if (state == AudioPlaybackState.FAILED) player.retry() else player.togglePlayback() }
            }
            if (context is PlaybackContext.Podcast) {
                Box(Modifier.size(36.dp).plainClickable { player.skip(30.0) }, contentAlignment = Alignment.Center) { SkipIcon(30, forward = true, 22.dp) }
            } else {
                IconTap(
                    Icons.Default.FastForward, "Siguiente", iconSize = 20.dp,
                    tint = if (canAdvance) c.textPrimary else c.textSecondary, enabled = canAdvance,
                ) { player.next() }
            }
        }
        ProgressLine(if (duration > 0) (time / duration).toFloat() else 0f)
    }
}

/** Equivalente de `gobackward.15` / `goforward.30`: flecha circular con el número de segundos. */
@Composable
fun SkipIcon(seconds: Int, forward: Boolean, size: Dp, tint: androidx.compose.ui.graphics.Color = Donda.colors.textPrimary) {
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        Icon(Icons.Default.Replay, null, tint = tint, modifier = Modifier.size(size).scale(if (forward) -1f else 1f, 1f))
        DText("$seconds", size = (size.value * 0.3f).sp, color = tint, weight = FontWeight.Bold, modifier = Modifier.offset(y = (size.value * 0.06f).dp))
    }
}

// MARK: - Reproductor expandido (Donda)

@Composable
fun ExpandedPlayer(onDismiss: () -> Unit) {
    val app = LocalApp.current
    val player = app.player
    val c = Donda.colors
    val queueState by app.queue.state.collectAsState()
    val current = queueState.current ?: return
    val context by player.context.collectAsState()
    val state by player.playbackState.collectAsState()
    val radioSeed by player.radioSeedTitle.collectAsState()
    val error by player.errorMessage.collectAsState()
    val lastResume by player.lastResumeSeconds.collectAsState()
    val isPodcast = context is PlaybackContext.Podcast
    var tab by remember { mutableStateOf(PlayerTab.QUEUE) }
    val toast = rememberToast()

    LaunchedEffect(lastResume) { lastResume?.takeIf { it > 0 }?.let { toast.show("Reanudando en ${formatTime(it)}") } }
    LaunchedEffect(error) {
        error?.takeIf { it.contains("radio", ignoreCase = true) }?.let {
            toast.show(it)
            player.clearError()
        }
    }

    DondaSheet(onDismiss) {
        Box(Modifier.fillMaxSize().statusBarsPadding()) {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 22.dp, end = 22.dp, top = 16.dp, bottom = 32.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                PlayerHeader(current, context, radioSeed != null, onDismiss) { tab = PlayerTab.LYRICS }
                Artwork(current, state == AudioPlaybackState.PLAYING)
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    DTitle(current.title, 20.sp, maxLines = 2, align = TextAlign.Center)
                    DLabel(current.channelTitle, maxLines = 1, align = TextAlign.Center)
                    if (state == AudioPlaybackState.FAILED && error != null) {
                        DLabel(error!!, color = c.textPrimary, align = TextAlign.Center, modifier = Modifier.padding(top = 6.dp))
                        OutlineButton("Reintentar") { player.retry() }
                    }
                }
                ProgressSection(player)
                if (isPodcast) EpisodeControls(player, current) else MusicControls(player)
                if (isPodcast) {
                    val downloaded = downloadState(current.id) == DownloadState.Downloaded
                    DLabel(
                        "Se guarda la posición al pausar" + if (downloaded) " · Disponible sin conexión" else "",
                        size = 10.sp, align = TextAlign.Center, modifier = Modifier.padding(top = 4.dp),
                    )
                } else {
                    OutlineButton(if (radioSeed != null) "Radio activa · parar" else "Iniciar radio", horizontal = 16.dp, vertical = 10.dp) {
                        if (radioSeed != null) player.stopRadio() else player.startRadio()
                    }
                    PlayerTabs(tab) { tab = it }
                    if (tab == PlayerTab.QUEUE) {
                        UpcomingQueue(player, radioSeed)
                    } else {
                        val lyricsHeight = LocalConfiguration.current.screenHeightDp.dp * 0.6f
                        Box(Modifier.fillMaxWidth().height(lyricsHeight)) { LyricsContent(current) }
                    }
                }
            }
            toast.Host(this, inverted = false, durationMillis = 2_400)
        }
    }
}

/** Pestañas del reproductor (solo música). */
private enum class PlayerTab(val label: String) { QUEUE("A continuación"), LYRICS("Letras") }

@Composable
private fun PlayerTabs(selected: PlayerTab, onSelect: (PlayerTab) -> Unit) {
    val c = Donda.colors
    Row(Modifier.fillMaxWidth().border(1.dp, c.outline, RectangleShape)) {
        PlayerTab.entries.forEach { tab ->
            val active = tab == selected
            Box(
                Modifier.weight(1f).height(40.dp)
                    .background(if (active) c.textPrimary else c.background)
                    .plainClickable { onSelect(tab) },
                contentAlignment = Alignment.Center,
            ) { DLabel(tab.label, color = if (active) c.background else c.textPrimary, maxLines = 1) }
        }
    }
}

@Composable
private fun PlayerHeader(current: MediaItem, context: PlaybackContext, radio: Boolean, onDismiss: () -> Unit, onLyrics: () -> Unit) {
    val nav = LocalNav.current
    val c = Donda.colors
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.width(116.dp)) { IconTap(Icons.Default.KeyboardArrowDown, "Cerrar", iconSize = 22.dp, onClick = onDismiss) }
        Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
            if (context is PlaybackContext.Podcast) {
                DLabel(current.channelTitle, maxLines = 1, modifier = Modifier.plainClickable {
                    onDismiss()
                    nav.navigate(Destination.PodcastDetail(context.channelId, current.channelTitle))
                })
            } else {
                DLabel(if (radio) "Radio" else "Reproduciendo", maxLines = 1)
            }
        }
        Row(Modifier.width(116.dp), horizontalArrangement = Arrangement.End) {
            if (context !is PlaybackContext.Podcast) {
                IconTap(Icons.Default.FormatQuote, "Letras de la canción", tint = c.textSecondary, iconSize = 18.dp, onClick = onLyrics)
                FavoriteButton(current)
            }
            PlayerMenu(current, onDismiss)
        }
    }
}

@Composable
private fun PlayerMenu(current: MediaItem, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val saved by app.library.savedAlbums.collectAsState()
    val isSaved = saved.any { it.id.equals(current.title, true) || it.title.equals(current.title, true) }
    var open by remember { mutableStateOf(false) }
    Box {
        IconTap(Icons.Default.MoreHoriz, "Más opciones de reproducción", tint = Donda.colors.textSecondary, iconSize = 18.dp) { open = true }
        DondaMenu(open, { open = false }) {
            DondaMenuItem("Ir al álbum", Icons.Default.LibraryMusic) {
                open = false
                onDismiss()
                nav.navigate(Destination.AlbumDetail(current.title, current.title))
            }
            DondaMenuItem("Ir al artista", Icons.Default.Mic) {
                open = false
                onDismiss()
                nav.navigate(Destination.ArtistDetail(current.channelTitle, current.channelTitle))
            }
            AddToPlaylistItems(current) { open = false }
            DondaMenuItem(
                if (isSaved) "Quitar álbum de la biblioteca" else "Salvar álbum en la librería",
                if (isSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
            ) {
                app.library.toggleSaveAlbum(current.title, current.title, current.channelTitle, current.artworkUrl, listOf(current))
                open = false
            }
        }
    }
}

@Composable
private fun Artwork(current: MediaItem, playing: Boolean) {
    val c = Donda.colors
    // La carátula «respira» con una sombra mínima mientras suena.
    val pulse by rememberInfiniteTransition(label = "pulse").animateFloat(
        0f, 0.06f, infiniteRepeatable(tween(4_000), RepeatMode.Reverse), label = "alpha",
    )
    val glow = c.textPrimary.copy(alpha = if (playing) pulse else 0f)
    TrackArtwork(
        current.artworkUrl,
        Modifier.fillMaxWidth().aspectRatio(1f).shadow(40.dp, RectangleShape, clip = false, ambientColor = glow, spotColor = glow),
    )
}

@Composable
private fun ProgressSection(player: PlayerCoordinator) {
    val c = Donda.colors
    val time by player.currentTime.collectAsState()
    val duration by player.duration.collectAsState()
    var dragValue by remember { mutableStateOf<Double?>(null) }
    val shown = dragValue ?: time
    val max = maxOf(duration, 1.0)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        BoxWithConstraints(
            Modifier.fillMaxWidth().height(28.dp)
                .pointerInput(max) { detectTapGestures { player.seek((it.x / size.width).coerceIn(0f, 1f) * max) } }
                .pointerInput(max) {
                    detectHorizontalDragGestures(
                        onDragStart = { dragValue = (it.x / size.width).coerceIn(0f, 1f) * max },
                        onDragEnd = {
                            dragValue?.let(player::seek)
                            dragValue = null
                        },
                        onDragCancel = { dragValue = null },
                    ) { change, _ -> dragValue = (change.position.x / size.width).coerceIn(0f, 1f) * max }
                },
            contentAlignment = Alignment.CenterStart,
        ) {
            val fraction = (shown / max).toFloat().coerceIn(0f, 1f)
            ProgressLine(fraction)
            Box(Modifier.offset(x = (maxWidth - 10.dp) * fraction).size(10.dp).background(c.textPrimary))
        }
        Row {
            DText(formatTime(shown), size = 11.sp, mono = true, color = c.textSecondary)
            Spacer(Modifier.weight(1f))
            DText("-" + formatTime(maxOf(duration - shown, 0.0)), size = 11.sp, mono = true, color = c.textSecondary)
        }
    }
}

@Composable
private fun PlayPauseSquare(player: PlayerCoordinator) {
    val c = Donda.colors
    val state by player.playbackState.collectAsState()
    val playing = state == AudioPlaybackState.PLAYING
    Box(
        Modifier.size(72.dp).border(1.dp, c.textPrimary, RectangleShape).plainClickable { player.togglePlayback() },
        contentAlignment = Alignment.Center,
    ) {
        if (state == AudioPlaybackState.RESOLVING || state == AudioPlaybackState.BUFFERING) {
            CircularProgressIndicator(Modifier.size(22.dp), color = c.textPrimary, strokeWidth = 1.5.dp)
        } else {
            Icon(if (playing) Icons.Default.Pause else Icons.Default.PlayArrow, if (playing) "Pausar" else "Reproducir", tint = c.textPrimary, modifier = Modifier.size(30.dp))
        }
    }
}

@Composable
private fun MusicControls(player: PlayerCoordinator) {
    val app = LocalApp.current
    val c = Donda.colors
    val queueState by app.queue.state.collectAsState()
    val shuffle by player.shuffleEnabled.collectAsState()
    val repeat by player.repeatMode.collectAsState()
    val time by player.currentTime.collectAsState()
    val canAdvance = remember(queueState) { app.queue.canAdvance }
    val canRetreat = remember(queueState) { app.queue.canRetreat } || time >= 1
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
        ControlIcon(Icons.Default.Shuffle, "Barajar", if (shuffle) c.textPrimary else c.textSecondary, 22.dp) { player.toggleShuffle() }
        ControlIcon(Icons.Default.FastRewind, "Anterior", if (canRetreat) c.textPrimary else c.textSecondary, 26.dp, canRetreat) { player.previous() }
        PlayPauseSquare(player)
        ControlIcon(Icons.Default.FastForward, "Siguiente", if (canAdvance) c.textPrimary else c.textSecondary, 26.dp, canAdvance) { player.next() }
        ControlIcon(
            if (repeat == QueueRepeat.ONE) Icons.Default.RepeatOne else Icons.Default.Repeat, "Repetir",
            if (repeat == QueueRepeat.OFF) c.textSecondary else c.textPrimary, 22.dp,
        ) { player.cycleRepeat() }
    }
}

@Composable
private fun ControlIcon(icon: ImageVector, description: String, tint: androidx.compose.ui.graphics.Color, size: Dp, enabled: Boolean = true, onClick: () -> Unit) =
    IconTap(icon, description, size = 44.dp, iconSize = size, tint = tint, enabled = enabled, onClick = onClick)

@Composable
private fun EpisodeControls(player: PlayerCoordinator, current: MediaItem) {
    val app = LocalApp.current
    val c = Donda.colors
    val rate by app.settings.podcastRate.collectAsState()
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
        Box(
            Modifier.width(44.dp).height(32.dp).hairlineBorder(c.outline).plainClickable { app.settings.cyclePodcastRate() },
            contentAlignment = Alignment.Center,
        ) { DText(PlaybackSettings.formatRate(rate), size = 11.sp, mono = true, weight = FontWeight.SemiBold) }
        Box(Modifier.size(44.dp).plainClickable { player.skip(-15.0) }, contentAlignment = Alignment.Center) { SkipIcon(15, forward = false, 26.dp) }
        PlayPauseSquare(player)
        Box(Modifier.size(44.dp).plainClickable { player.skip(30.0) }, contentAlignment = Alignment.Center) { SkipIcon(30, forward = true, 26.dp) }
        val state = downloadState(current.id)
        Box(
            Modifier.size(44.dp).plainClickable {
                if (state == DownloadState.NotDownloaded || state is DownloadState.Failed) app.downloads.enqueue(current, app.resolver)
            },
            contentAlignment = Alignment.Center,
        ) {
            when (state) {
                DownloadState.Downloaded -> Icon(Icons.Default.Check, "Descargado", tint = c.textPrimary, modifier = Modifier.size(20.dp))
                is DownloadState.Downloading -> CircularProgressIndicator(Modifier.size(16.dp), color = c.textPrimary, strokeWidth = 1.5.dp)
                DownloadState.Queued -> Icon(Icons.Default.AccessTime, "En cola de descarga", tint = c.textSecondary, modifier = Modifier.size(20.dp))
                else -> Icon(Icons.Default.ArrowDownward, "Descargar episodio", tint = c.textSecondary, modifier = Modifier.size(20.dp))
            }
        }
    }
}

@Composable
private fun UpcomingQueue(player: PlayerCoordinator, radioSeed: String?) {
    val app = LocalApp.current
    val c = Donda.colors
    val queueState by app.queue.state.collectAsState()
    val window = queueState.upNextWindow()
    if (window.isEmpty()) return
    Column(Modifier.fillMaxWidth().padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        DLabel(radioSeed?.let { "Radio de “$it”" } ?: "A continuación")
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            window.forEach { (index, item) ->
                Row(Modifier.fillMaxWidth().plainClickable { player.selectFromQueue(index) }, verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.width(12.dp)) { if (index == queueState.currentIndex) DText("▶", size = 9.sp, mono = true) }
                    Spacer(Modifier.width(12.dp))
                    TrackArtwork(item.artworkUrl, Modifier.size(40.dp))
                    Column(Modifier.weight(1f).padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        DText(item.title, size = 13.sp, mono = true, maxLines = 1)
                        DText(item.channelTitle, size = 11.sp, mono = true, color = c.textSecondary, maxLines = 1)
                    }
                    item.durationSeconds?.takeIf { it > 0 }?.let {
                        DText(formatTime(it.toDouble()), size = 11.sp, mono = true, color = c.textSecondary)
                    }
                }
            }
        }
    }
}
