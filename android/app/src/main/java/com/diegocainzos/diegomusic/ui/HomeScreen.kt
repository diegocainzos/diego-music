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
import com.diegocainzos.diegomusic.core.MediaKind
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
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
    // Selecciones rápidas: 20 canciones al azar de la biblioteca, nuevas al volver a la app.
    var quickPicks by remember { mutableStateOf(emptyList<MediaItem>()) }
    fun shuffle() { quickPicks = favorites.shuffled().take(20).map { it.mediaItem } }
    LaunchedEffect(favorites.size) { shuffle() }
    val lifecycle = androidx.lifecycle.compose.LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, e -> if (e == Lifecycle.Event.ON_RESUME) shuffle() }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
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

        // Selecciones rápidas
        if (quickPicks.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Selecciones rápidas")
                CompactGrid(quickPicks) { app.play(it) }
            }
        }

        // Escuchado hace poco
        val recent = remember(history) { HomeLogic.distinctRecent(history.map { it.mediaItem }) }
        if (recent.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Escuchado hace poco")
                CompactGrid(recent) { app.play(it) }
            }
        }

        DiscoverySection()

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

        BottomInsetSpacer(40.dp)
    }
}

@Composable
private fun CompactGrid(items: List<MediaItem>, onClick: (MediaItem) -> Unit) {
    val cellWidth = minOf(LocalConfiguration.current.screenWidthDp.dp * 0.85f, 360.dp)
    LazyHorizontalGrid(
        rows = GridCells.Fixed(4),
        modifier = Modifier.fillMaxWidth().height(56.dp * 4 + 8.dp * 3),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(items, key = { it.id }) { item ->
            Row(
                Modifier.width(cellWidth).height(56.dp).plainClickable { onClick(item) },
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

@Composable
private fun ChipGroup(title: String, options: List<String>, selected: String?, onSelect: (String?) -> Unit) {
    val c = Donda.colors
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        DLabel(title)
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            options.forEach { o ->
                val on = o == selected
                Box(
                    Modifier.background(if (on) c.textPrimary else c.background).hairlineBorder(c.outline)
                        .plainClickable { onSelect(if (on) null else o) }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                ) { DLabel(o, color = if (on) c.background else c.textPrimary, maxLines = 1) }
            }
        }
    }
}

@Composable
private fun DiscoverySection() {
    val app = LocalApp.current
    var genre by rememberSaveable { mutableStateOf<String?>(null) }
    var vibe by rememberSaveable { mutableStateOf<String?>(null) }
    var decade by rememberSaveable { mutableStateOf<String?>(null) }
    var country by rememberSaveable { mutableStateOf<String?>(null) }
    var results by remember { mutableStateOf<List<MediaItem>?>(null) }
    var failed by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    var searchJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    val query = HomeLogic.discoveryQuery(genre, vibe, decade, country)

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionHeader("Descubrimiento")
        ChipGroup("Género", DiscoveryChips.genre, genre) { genre = it }
        ChipGroup("Vibra", DiscoveryChips.vibe, vibe) { vibe = it }
        ChipGroup("Década", DiscoveryChips.decade, decade) { decade = it }
        ChipGroup("País", DiscoveryChips.country, country) { country = it }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            OutlineButton("Buscar", enabled = query != null) {
                val q = query ?: return@OutlineButton
                failed = false
                searchJob?.cancel()
                searchJob = scope.launch {
                    try {
                        results = app.youtube.search("$q official").items.filter { it.kind == MediaKind.VIDEO && HomeLogic.looksLikeSong(it.title) }.take(20)
                        failed = false
                    } catch (e: CancellationException) {
                        throw e
                    } catch (_: Exception) {
                        results = null
                        failed = true
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            val r = results
            if (r != null && r.isNotEmpty()) OutlineButton("Reproducir todo") { app.playQueue(r, 0) }
        }
        val r = results
        when {
            failed -> DLabel("No se pudo buscar.")
            r != null && r.isEmpty() -> DLabel("Sin resultados")
            r != null -> CompactGrid(r) { app.play(it) }
        }
    }
}
