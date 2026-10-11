package com.diegocainzos.diegomusic.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.DiscoveryFeed
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.formatRemaining
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
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
    var recommendations by remember { mutableStateOf<List<MediaItem>>(emptyList()) }

    LaunchedEffect(Unit) { feed = app.youtube.discover() }
    // El historial llega tras sincronizar con el backend: se piden las recomendaciones cuando existe.
    val hasHistory = history.isNotEmpty()
    LaunchedEffect(hasHistory) {
        // Best-effort: si el LLM o el resolutor fallan, la sección no aparece.
        if (hasHistory) {
            recommendations = runCatching { app.youtube.recommendations(app.library.history.value.map { it.mediaItem }) }.getOrDefault(emptyList())
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

        if (recommendations.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("Para ti")
                CardCarousel(recommendations, { it.id }, { it.artworkUrl }, { app.play(it) }) { MediaCardTitle(it.title, it.channelTitle) }
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
