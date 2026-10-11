@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)

package com.diegocainzos.diegomusic.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.Album
import com.diegocainzos.diegomusic.core.ArtistDetail
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.player.AudioPlaybackState
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.Hairline
import com.diegocainzos.diegomusic.ui.theme.IconTap
import com.diegocainzos.diegomusic.ui.theme.OutlineButton
import com.diegocainzos.diegomusic.ui.theme.PrimaryButton
import com.diegocainzos.diegomusic.ui.theme.SectionHeader
import com.diegocainzos.diegomusic.ui.theme.TrackArtwork
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.plainClickable
import kotlinx.coroutines.CancellationException

sealed interface Load<out T> {
    object Loading : Load<Nothing>
    data class Loaded<T>(val value: T) : Load<T>
    data class Failed(val message: String) : Load<Nothing>
}

/** Carga asíncrona con reintento (equivale a los `ViewModel` de Artista/Álbum en Swift). */
@Composable
fun <T> rememberLoad(key: Any, fallbackMessage: String, block: suspend () -> T): Pair<Load<T>, () -> Unit> {
    var attempt by remember { mutableIntStateOf(0) }
    var state by remember(key) { mutableStateOf<Load<T>>(Load.Loading) }
    LaunchedEffect(key, attempt) {
        state = Load.Loading
        state = try {
            Load.Loaded(block())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Load.Failed(e.message ?: fallbackMessage)
        }
    }
    return state to { attempt++ }
}

@Composable
private fun <T> LoadContent(state: Load<T>, loadingText: String, retry: () -> Unit, content: @Composable (T) -> Unit) {
    val c = Donda.colors
    when (state) {
        Load.Loading -> LoadingLabel(loadingText, Modifier.fillMaxWidth().padding(top = 60.dp))
        is Load.Failed -> Column(
            Modifier.fillMaxWidth().padding(top = 60.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(Icons.Outlined.WarningAmber, null, tint = c.textSecondary, modifier = Modifier.size(28.dp))
            DText(state.message, size = 15.sp, color = c.textSecondary, align = TextAlign.Center)
            PrimaryButton("Reintentar", onClick = retry)
        }
        is Load.Loaded -> content(state.value)
    }
}

// MARK: - Artista

@Composable
fun ArtistScreen(artistId: String, artistTitle: String) {
    val app = LocalApp.current
    val toast = rememberToast()
    val (state, retry) = rememberLoad(artistId, "No se pudo cargar el artista.") { app.youtube.artist(artistId) }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            BackBar("Artista")
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.spacedBy(32.dp),
            ) {
                LoadContent(state, "Cargando perfil de $artistTitle…", retry) { detail ->
                    ArtistHeader(detail, artistTitle, toast)
                    TopTracks(detail.topTracks, toast)
                    Discography(detail.albums)
                    SimilarArtists(detail.related)
                }
                BottomInsetSpacer()
            }
        }
        toast.Host(this)
    }
}

@Composable
private fun ArtistHeader(detail: ArtistDetail, fallbackTitle: String, toast: ToastState) {
    val app = LocalApp.current
    val c = Donda.colors
    val title = detail.artist.title.ifEmpty { fallbackTitle }
    var following by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        TrackArtwork(detail.artist.thumbnailUrl, Modifier.size(150.dp))
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            DLabel("Artista")
            DTitle(title, 26.sp, align = TextAlign.Center)
            detail.artist.bio?.takeIf { it.isNotEmpty() }?.let {
                DText(it, size = 12.sp, color = c.textSecondary, maxLines = 3, align = TextAlign.Center, modifier = Modifier.padding(horizontal = 12.dp))
            }
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            InvertedAction("Reproducir", Icons.Default.PlayArrow) { detail.topTracks.firstOrNull()?.let(app::play) }
            OutlineButton("Aleatorio", icon = Icons.Default.Shuffle, horizontal = 20.dp, vertical = 10.dp) {
                detail.topTracks.randomOrNull()?.let(app::play)
            }
            OutlineButton(
                if (following) "Siguiendo" else "Seguir",
                icon = if (following) Icons.Default.Check else Icons.Default.Add,
                selected = following, horizontal = 18.dp, vertical = 10.dp,
            ) {
                following = !following
                toast.show(if (following) "Siguiendo a $title" else "Dejaste de seguir a $title")
            }
        }
    }
}

@Composable
private fun InvertedAction(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    val c = Donda.colors
    Row(
        Modifier.background(c.textPrimary).plainClickable(onClick = onClick).padding(horizontal = 20.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = c.background, modifier = Modifier.size(12.dp))
        Spacer(Modifier.width(8.dp))
        DLabel(text, color = c.background)
    }
}

@Composable
private fun TopTracks(items: List<MediaItem>, toast: ToastState) {
    val app = LocalApp.current
    val c = Donda.colors
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionHeader("Éxitos populares")
        if (items.isEmpty()) {
            DText("No hay canciones populares disponibles.", size = 15.sp, color = c.textSecondary)
        } else {
            Column(Modifier.hairlineBorder(c.hairline)) {
                val top = items.take(10)
                top.forEachIndexed { index, item ->
                    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Row(Modifier.weight(1f).plainClickable { app.play(item) }, verticalAlignment = Alignment.CenterVertically) {
                            DLabel("${index + 1}", modifier = Modifier.width(24.dp), align = TextAlign.Center)
                            Spacer(Modifier.width(12.dp))
                            TrackArtwork(item.artworkUrl, Modifier.size(44.dp))
                            Column(Modifier.padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                DText(item.title, maxLines = 1)
                                DLabel(item.channelTitle, maxLines = 1)
                            }
                        }
                        IconTap(Icons.Default.PlayArrow, "Reproducir ${item.title}", size = 32.dp, iconSize = 13.dp) { app.play(item) }
                        FavoriteButton(item, size = 32.dp, iconSize = 13.dp)
                        TrackMenuButton(item, toast, showArtist = false)
                    }
                    if (index < top.size - 1) Hairline(Modifier.padding(start = 48.dp))
                }
            }
        }
    }
}

@Composable
private fun Discography(albums: List<Album>) {
    val nav = LocalNav.current
    val c = Donda.colors
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            DLabel("Discografía y álbumes", tracking = 4.sp, modifier = Modifier.weight(1f))
            if (albums.isNotEmpty()) DLabel("${albums.size} lanzamientos")
        }
        if (albums.isEmpty()) {
            DText("No hay álbumes disponibles.", size = 15.sp, color = c.textSecondary)
        } else {
            albums.chunked(2).forEach { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    pair.forEach { album ->
                        Column(
                            Modifier.weight(1f).plainClickable { nav.navigate(Destination.AlbumDetail(album.id, album.title)) },
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            TrackArtwork(album.thumbnailUrl, Modifier.fillMaxWidth().aspectRatio(1f))
                            DText(album.title, maxLines = 2)
                            DLabel(album.channelTitle ?: "Álbum", maxLines = 1)
                        }
                    }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun SimilarArtists(items: List<MediaItem>) {
    val nav = LocalNav.current
    val c = Donda.colors
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        SectionHeader("Artistas similares")
        if (items.isEmpty()) {
            DText("No hay artistas similares recomendados.", size = 15.sp, color = c.textSecondary)
        } else {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                items(items.takeLast(6), key = { it.id }) { item ->
                    Column(
                        Modifier.width(110.dp).plainClickable { nav.navigate(Destination.ArtistDetail(item.channelTitle, item.channelTitle)) },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        TrackArtwork(item.artworkUrl, Modifier.size(110.dp))
                        DText(item.channelTitle, size = 13.sp, maxLines = 1)
                    }
                }
            }
        }
    }
}

// MARK: - Álbum

@Composable
fun AlbumScreen(playlistId: String) {
    val app = LocalApp.current
    val toast = rememberToast()
    val (state, retry) = rememberLoad(playlistId, "No se pudo cargar el álbum.") { app.youtube.album(playlistId) }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            BackBar("Álbum")
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.spacedBy(32.dp),
            ) {
                LoadContent(state, "Cargando álbum…", retry) { album ->
                    LaunchedEffect(album.id) { app.player.warm(album.tracks) }
                    AlbumHeader(album, toast)
                    AlbumTracks(album.tracks, toast)
                }
                BottomInsetSpacer()
            }
        }
        toast.Host(this)
    }
}

@Composable
private fun AlbumHeader(album: Album, toast: ToastState) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val c = Donda.colors
    val saved by app.library.savedAlbums.collectAsState()
    val isSaved = saved.any { it.id.equals(album.id, true) || it.title.equals(album.id, true) || it.title.equals(album.title, true) }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            DLabel("Álbum")
            DTitle(album.title, 24.sp, maxLines = 2, align = TextAlign.Center)
        }
        TrackArtwork(album.thumbnailUrl, Modifier.size(190.dp))
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            album.channelTitle?.takeIf { it.isNotEmpty() }?.let { channel ->
                OutlineButton(channel, icon = Icons.Default.Person, horizontal = 12.dp, vertical = 6.dp) {
                    nav.navigate(Destination.ArtistDetail(channel, channel))
                }
            }
            DLabel("${album.tracks.size} canciones")
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            InvertedAction("Reproducir", Icons.Default.PlayArrow) { app.playQueue(album.tracks, 0) }
            Box(
                Modifier.size(38.dp).hairlineBorder(c.outline).plainClickable {
                    album.tracks.randomOrNull()?.let { first -> app.playQueue(listOf(first) + album.tracks.filter { it.id != first.id }.shuffled(), 0) }
                },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.Shuffle, "Reproducir álbum en modo aleatorio", tint = c.textPrimary, modifier = Modifier.size(14.dp)) }
            if (album.tracks.isNotEmpty()) DownloadAllButton(album.tracks)
            Box(
                Modifier.size(38.dp).background(if (isSaved) c.textPrimary else c.background).hairlineBorder(c.outline).plainClickable {
                    app.library.toggleSaveAlbum(album)
                    toast.show(if (!isSaved) "Álbum guardado en la biblioteca" else "Álbum eliminado de la biblioteca")
                },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (isSaved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                    if (isSaved) "Eliminar álbum de la biblioteca" else "Guardar álbum en la biblioteca",
                    tint = if (isSaved) c.background else c.textPrimary, modifier = Modifier.size(14.dp),
                )
            }
        }
    }
}

@Composable
private fun AlbumTracks(items: List<MediaItem>, toast: ToastState) {
    val app = LocalApp.current
    val c = Donda.colors
    val queueState by app.queue.state.collectAsState()
    val playback by app.player.playbackState.collectAsState()
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row {
            DLabel("Canciones", tracking = 4.sp, modifier = Modifier.weight(1f))
            DLabel("${items.size} pistas")
        }
        if (items.isEmpty()) {
            DText("Este álbum no contiene pistas reproducibles.", size = 15.sp, color = c.textSecondary, align = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 16.dp))
            return
        }
        Column(Modifier.hairlineBorder(c.hairline)) {
            items.forEachIndexed { index, item ->
                val isCurrent = queueState.current?.id == item.id
                Row(
                    Modifier.fillMaxWidth().background(if (isCurrent) c.hairline else c.background).padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Row(Modifier.weight(1f).plainClickable { app.playQueue(items, index) }, verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(24.dp), contentAlignment = Alignment.Center) {
                            val icon = when {
                                isCurrent && playback == AudioPlaybackState.PLAYING -> Icons.Default.GraphicEq
                                isCurrent -> Icons.Default.Pause
                                else -> Icons.Default.PlayArrow
                            }
                            Icon(icon, null, tint = if (isCurrent) c.textPrimary else c.textSecondary.copy(alpha = 0.6f), modifier = Modifier.size(13.dp))
                        }
                        Column(Modifier.padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            DText(item.title, maxLines = 1, weight = if (isCurrent) FontWeight.Medium else FontWeight.Normal)
                            DLabel(item.channelTitle, maxLines = 1)
                        }
                    }
                    FavoriteButton(item, size = 32.dp, iconSize = 13.dp)
                    TrackMenuButton(item, toast, showAlbum = false)
                }
                if (index < items.size - 1) Hairline(Modifier.padding(start = 48.dp))
            }
        }
    }
}
