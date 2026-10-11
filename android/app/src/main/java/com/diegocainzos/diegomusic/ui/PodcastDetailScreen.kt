package com.diegocainzos.diegomusic.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.PodcastShow
import com.diegocainzos.diegomusic.core.formatHoursMinutes
import com.diegocainzos.diegomusic.core.formatRemaining
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.Hairline
import com.diegocainzos.diegomusic.ui.theme.OutlineButton
import com.diegocainzos.diegomusic.ui.theme.ProgressLine
import com.diegocainzos.diegomusic.ui.theme.TrackArtwork
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.plainClickable
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant

@Composable
fun PodcastDetailScreen(channelId: String, title: String) {
    val app = LocalApp.current
    val c = Donda.colors
    val scope = rememberCoroutineScope()
    val shows by app.library.followedShows.collectAsState()
    val progressVersion by app.library.progressVersion.collectAsState()
    val following = shows.any { it.channelId == channelId }

    var episodes by remember { mutableStateOf<List<MediaItem>>(emptyList()) }
    var hidden by remember { mutableIntStateOf(0) }
    var nextToken by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(true) }
    var loadingMore by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var attempt by remember { mutableIntStateOf(0) }

    LaunchedEffect(channelId, attempt) {
        loading = true
        failed = false
        try {
            val page = app.youtube.podcastEpisodes(channelId)
            episodes = page.episodes
            hidden = page.hiddenShortCount
            nextToken = page.nextPageToken
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (_: Exception) {
            failed = true
        }
        loading = false
    }

    val thumbnail = shows.firstOrNull { it.channelId == channelId }?.thumbnailUrl ?: episodes.firstOrNull()?.artworkUrl
    val progressById = remember(episodes, progressVersion) { episodes.associate { it.id to app.library.progress(it.id) } }
    val target = episodes.firstOrNull { progressById[it.id]?.let { p -> !p.finished && p.position > 0 } == true } ?: episodes.firstOrNull()

    Column(Modifier.fillMaxSize()) {
        BackBar("")
        LazyColumn(contentPadding = PaddingValues(bottom = 32.dp + LocalBottomInset.current)) {
            item {
                Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row(verticalAlignment = Alignment.Top) {
                        TrackArtwork(thumbnail, Modifier.size(118.dp))
                        Column(Modifier.padding(start = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            DLabel("Podcast · YouTube")
                            DTitle(title, 22.sp, maxLines = 3)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                if (target != null) {
                                    val inProgress = progressById[target.id]?.let { !it.finished && it.position > 0 } == true
                                    Row(
                                        Modifier.background(c.textPrimary).plainClickable { app.playEpisode(target, channelId) }
                                            .padding(horizontal = 14.dp, vertical = 8.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Icon(Icons.Default.PlayArrow, null, tint = c.background, modifier = Modifier.size(12.dp))
                                        Spacer(Modifier.width(6.dp))
                                        DLabel(if (inProgress) "Reanudar" else "Reproducir", color = c.background)
                                    }
                                }
                                OutlineButton(if (following) "Siguiendo" else "Seguir", selected = following) {
                                    if (following) app.library.unfollow(channelId) else app.library.follow(PodcastShow(channelId, title, thumbnail))
                                }
                            }
                        }
                    }
                    DLabel("Solo episodios completos · $hidden vídeos de menos de 40 min ocultos")
                }
            }
            when {
                loading -> item { LoadingLabel("Cargando episodios…", Modifier.fillMaxWidth().padding(vertical = 48.dp)) }
                failed -> item {
                    Column(Modifier.fillMaxWidth().padding(vertical = 48.dp, horizontal = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        DLabel("No se pudieron cargar los episodios.", align = TextAlign.Center)
                        OutlineButton("Reintentar") { attempt++ }
                    }
                }
                episodes.isEmpty() -> item { DLabel("No hay episodios disponibles.", Modifier.fillMaxWidth().padding(vertical = 48.dp), align = TextAlign.Center) }
                else -> {
                    items(episodes, key = { it.id }) { episode ->
                        val p = progressById[episode.id]
                        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                            Row(Modifier.weight(1f).plainClickable { app.playEpisode(episode, channelId) }, verticalAlignment = Alignment.CenterVertically) {
                                TrackArtwork(episode.artworkUrl, Modifier.size(52.dp))
                                Column(Modifier.padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    episode.publishedAt?.let { DLabel(relativeDate(it)) }
                                    DText(episode.title, maxLines = 2)
                                    when {
                                        p != null && p.finished -> DLabel("Escuchado")
                                        p != null && p.position > 0 -> {
                                            DLabel("Quedan ${formatRemaining(p.position, p.duration)}")
                                            ProgressLine((p.position / maxOf(1.0, p.duration)).toFloat())
                                        }
                                        episode.durationSeconds != null -> DLabel(formatHoursMinutes(episode.durationSeconds))
                                    }
                                }
                            }
                            EpisodeDownloadButton(episode)
                        }
                        Hairline()
                    }
                    if (nextToken != null) {
                        item {
                            Box(
                                Modifier.padding(16.dp).fillMaxWidth().hairlineBorder(c.outline).plainClickable(enabled = !loadingMore) {
                                    val token = nextToken ?: return@plainClickable
                                    loadingMore = true
                                    scope.launch {
                                        runCatching { app.youtube.podcastEpisodes(channelId, token) }.getOrNull()?.let { page ->
                                            val known = episodes.map { it.id }.toSet()
                                            episodes = episodes + page.episodes.filter { it.id !in known }
                                            hidden += page.hiddenShortCount
                                            nextToken = page.nextPageToken
                                        }
                                        loadingMore = false
                                    }
                                }.padding(vertical = 14.dp),
                                contentAlignment = Alignment.Center,
                            ) { DLabel(if (loadingMore) "Cargando…" else "Cargar más episodios", color = c.textPrimary) }
                        }
                    }
                }
            }
        }
    }
}

/** «HACE 3 DÍAS», «AYER»… (equivalente aproximado de `RelativeDateTimeFormatter` en español). */
fun relativeDate(date: Instant, now: Instant = Instant.now()): String {
    val days = Duration.between(date, now).toDays()
    return when {
        days < 0 -> "PRÓXIMAMENTE"
        days == 0L -> "HOY"
        days == 1L -> "AYER"
        days < 7 -> "HACE $days DÍAS"
        days < 14 -> "HACE 1 SEMANA"
        days < 30 -> "HACE ${days / 7} SEMANAS"
        days < 60 -> "HACE 1 MES"
        days < 365 -> "HACE ${days / 30} MESES"
        days < 730 -> "HACE 1 AÑO"
        else -> "HACE ${days / 365} AÑOS"
    }
}
