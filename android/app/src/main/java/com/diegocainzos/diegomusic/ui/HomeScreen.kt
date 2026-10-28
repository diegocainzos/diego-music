package com.diegocainzos.diegomusic.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyHorizontalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.DiscoveryFeed
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.formatRemaining
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.OutlineButton
import com.diegocainzos.diegomusic.ui.theme.ProgressLine
import com.diegocainzos.diegomusic.ui.theme.SectionHeader
import com.diegocainzos.diegomusic.ui.theme.TrackArtwork
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.plainClickable

@Composable
fun HomeScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val c = Donda.colors
    val history by app.library.history.collectAsState()
    val favorites by app.library.favorites.collectAsState()
    val shows by app.library.followedShows.collectAsState()
    val progressVersion by app.library.progressVersion.collectAsState()
    var feed by remember { mutableStateOf<DiscoveryFeed?>(null) }
    var quickPicks by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    val seed = history.firstOrNull()?.mediaItem

    LaunchedEffect(Unit) { feed = app.youtube.discover() }
    // Selecciones rápidas: Mix de la pista más reciente sin ella. Best-effort: fallo o vacío → sección oculta.
    LaunchedEffect(seed?.id) {
        quickPicks = emptyList()
        if (seed != null) {
            quickPicks = runCatching { app.youtube.radio(seed.id) }.getOrDefault(emptyList()).filter { it.id != seed.id }.take(20)
        }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(28.dp),
    ) {
        DTitle("DiegoMusic", 14.sp, tracking = 6.sp, modifier = Modifier.fillMaxWidth().padding(top = 36.dp), align = androidx.compose.ui.text.style.TextAlign.Center)

        // 1. Continuar (episodio a medias)
        val progress = remember(progressVersion) { app.library.latestUnfinishedEpisodeProgress() }
        if (progress != null) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Continuar")
                Row(
                    Modifier.fillMaxWidth().background(c.background).hairlineBorder(c.outline)
                        .plainClickable { app.playEpisode(progress.mediaItem, progress.channelId) }
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TrackArtwork(progress.thumbnailUrl, Modifier.size(64.dp))
                    Column(Modifier.weight(1f).padding(horizontal = 14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        DLabel(progress.channelTitle, maxLines = 1)
                        DText(progress.title, maxLines = 2)
                        DLabel("Quedan ${formatRemaining(progress.position, progress.duration)}")
                        ProgressLine((progress.position / maxOf(1.0, progress.duration)).toFloat())
                    }
                    Box(
                        Modifier.size(48.dp).background(c.textPrimary).plainClickable { app.playEpisode(progress.mediaItem, progress.channelId) },
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Default.PlayArrow, "Reanudar ${progress.title}", tint = c.background, modifier = Modifier.size(20.dp)) }
                }
            }
        }

        // 1b. Selecciones rápidas (Mix de la última pista): rejilla horizontal de 4 filas.
        if (seed != null && quickPicks.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    DLabel("Selecciones rápidas", modifier = Modifier.weight(1f), tracking = 4.sp, maxLines = 1)
                    OutlineButton("Reproducir todo") { app.playQueue(quickPicks, 0) }
                }
                val cellWidth = minOf(LocalConfiguration.current.screenWidthDp.dp * 0.85f, 360.dp)
                LazyHorizontalGrid(
                    rows = GridCells.Fixed(4),
                    modifier = Modifier.fillMaxWidth().height(56.dp * 4 + 8.dp * 3),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(quickPicks, key = { it.id }) { item ->
                        Row(
                            Modifier.width(cellWidth).height(56.dp).plainClickable { app.play(item) },
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            TrackArtwork(item.artworkUrl, Modifier.size(48.dp))
                            Column(Modifier.weight(1f).padding(start = 12.dp), verticalArrangement = Arrangement.Center) {
                                DText(item.title, size = 15.sp, weight = FontWeight.SemiBold, maxLines = 1)
                                DLabel(item.channelTitle, maxLines = 1)
                            }
                        }
                    }
                }
            }
        }

        // 2. Escuchado hace poco
        if (history.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Escuchado hace poco")
                CardCarousel(history.distinctBy { it.videoId }.take(10), { it.videoId }, { it.thumbnailUrl }, { app.play(it.mediaItem) }) {
                    MediaCardTitle(it.title, it.channelTitle)
                }
            }
        }

        // 3. Tus podcasts
        if (shows.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Tus podcasts")
                CardCarousel(shows, { it.channelId }, { it.thumbnailUrl }, { nav.navigate(Destination.PodcastDetail(it.channelId, it.title)) }) {
                    DLabel(it.title, color = c.textPrimary, maxLines = 2)
                }
            }
        }

        if (favorites.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Favoritos")
                CardCarousel(favorites, { it.videoId }, { it.thumbnailUrl }, { app.play(it.mediaItem) }) { MediaCardTitle(it.title, it.channelTitle) }
            }
        }

        feed?.takeIf { it.novedades.isNotEmpty() }?.let { f ->
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Descubrimiento")
                CardCarousel(f.novedades, { it.id }, { it.artworkUrl }, { app.play(it) }) { MediaCardTitle(it.title, it.channelTitle) }
            }
        }

        feed?.takeIf { it.artistas.isNotEmpty() }?.let { f ->
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Artistas destacados")
                CardCarousel(f.artistas, { it.id }, { it.thumbnailUrl }, { nav.navigate(Destination.ArtistDetail(it.id, it.title)) }) {
                    DLabel(it.title, color = c.textPrimary, maxLines = 2)
                }
            }
        }

        // Más escuchadas: historial agrupado por pista, ordenado por número de reproducciones.
        val top = remember(history) {
            history.groupBy { it.videoId }.values.sortedByDescending { it.size }.map { it.first() }
        }
        if (top.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Más escuchadas")
                CardCarousel(top, { it.videoId }, { it.thumbnailUrl }, { app.play(it.mediaItem) }) { MediaCardTitle(it.title, it.channelTitle) }
            }
        }

        BottomInsetSpacer(40.dp)
    }
}
