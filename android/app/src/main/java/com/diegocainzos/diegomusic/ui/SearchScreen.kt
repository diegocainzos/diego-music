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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CallMade
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Podcasts
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.MediaKind
import com.diegocainzos.diegomusic.core.PodcastShow
import com.diegocainzos.diegomusic.ui.theme.DChip
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.EmptyState
import com.diegocainzos.diegomusic.ui.theme.Hairline
import com.diegocainzos.diegomusic.ui.theme.IconTap
import com.diegocainzos.diegomusic.ui.theme.OutlineButton
import com.diegocainzos.diegomusic.ui.theme.TrackArtwork
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.plainClickable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** Ámbitos de búsqueda: filtran en el cliente los mismos resultados (sin peticiones extra). */
enum class SearchScope(val title: String) {
    ALL("Todo"), CANCIONES("Canciones"), ALBUMES("Álbumes"), ARTISTAS("Artistas"), LETRAS("Letras");

    fun matches(item: MediaItem, query: String): Boolean = when (this) {
        ALL -> true
        CANCIONES -> item.kind == MediaKind.VIDEO
        ALBUMES -> item.kind == MediaKind.PLAYLIST || item.kind == MediaKind.VIDEO
        ARTISTAS -> item.kind == MediaKind.CHANNEL
        LETRAS -> query.isBlank() || item.title.contains(query.trim(), true) || item.channelTitle.contains(query.trim(), true)
    }
}

private sealed interface SearchUi {
    object Idle : SearchUi
    object Loading : SearchUi
    data class Loaded(val items: List<MediaItem>) : SearchUi
    data class Failed(val message: String) : SearchUi
}

@Composable
fun SearchScreen() {
    val app = LocalApp.current
    val c = Donda.colors
    val scope = rememberCoroutineScope()
    val focus = LocalFocusManager.current
    val toast = rememberToast()
    var query by rememberSaveable { mutableStateOf("") }
    var activeScope by rememberSaveable { mutableStateOf(SearchScope.ALL) }
    var recent by remember { mutableStateOf(app.settings.recentQueries()) }
    var ui by remember { mutableStateOf<SearchUi>(SearchUi.Idle) }
    var job by remember { mutableStateOf<Job?>(null) }

    fun clear() {
        job?.cancel()
        ui = SearchUi.Idle
    }

    fun search() {
        val normalized = query.trim()
        if (normalized.isEmpty()) return clear()
        focus.clearFocus()
        job?.cancel()
        ui = SearchUi.Loading
        job = scope.launch {
            ui = try {
                val page = app.youtube.search(normalized)
                recent = app.settings.recordQuery(normalized)
                SearchUi.Loaded(page.items)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                SearchUi.Failed(e.message ?: "No se pudo completar la búsqueda.")
            }
        }
    }

    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            Column(Modifier.padding(bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                DTitle("Buscar", 14.sp, tracking = 6.sp, modifier = Modifier.fillMaxWidth().padding(top = 12.dp), align = TextAlign.Center)
                Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        Modifier.weight(1f).height(44.dp).background(c.background).hairlineBorder(c.hairline).padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Default.Search, null, tint = c.textSecondary, modifier = Modifier.size(15.dp))
                        Spacer(Modifier.width(10.dp))
                        BasicTextField(
                            value = query,
                            onValueChange = { query = it },
                            singleLine = true,
                            textStyle = TextStyle(color = c.textPrimary, fontSize = 13.sp, fontFamily = Donda.mono),
                            cursorBrush = SolidColor(c.textPrimary),
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search, autoCorrectEnabled = false),
                            keyboardActions = KeyboardActions(onSearch = { search() }),
                            modifier = Modifier.weight(1f),
                            decorationBox = { inner ->
                                Box(contentAlignment = Alignment.CenterStart) {
                                    if (query.isEmpty()) DLabel("Canciones, artistas, podcasts", maxLines = 1)
                                    inner()
                                }
                            },
                        )
                        if (query.isNotEmpty()) {
                            IconTap(Icons.Default.Close, "Borrar búsqueda", size = 28.dp, iconSize = 14.dp, tint = c.textSecondary) {
                                query = ""
                                clear()
                            }
                        }
                    }
                    Box(
                        Modifier.height(44.dp).background(c.textPrimary).plainClickable { search() }.padding(horizontal = 14.dp),
                        contentAlignment = Alignment.Center,
                    ) { DLabel("Buscar", color = c.background) }
                }
                LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(SearchScope.entries) { s -> DChip(s.title, activeScope == s) { activeScope = s } }
                }
            }

            when (val state = ui) {
                SearchUi.Idle -> if (recent.isEmpty()) {
                    EmptyState(
                        "Tu próxima escucha", Icons.Default.Podcasts, "Escribe una consulta para explorar vídeos y podcasts.",
                        Modifier.fillMaxSize().padding(top = 40.dp),
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        DLabel("Reciente", tracking = 4.sp, modifier = Modifier.padding(horizontal = 16.dp))
                        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = LocalBottomInset.current), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            items(recent) { q ->
                                Row(
                                    Modifier.fillMaxWidth().background(c.background).hairlineBorder(c.hairline)
                                        .plainClickable { query = q; search() }.padding(horizontal = 14.dp, vertical = 10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Icon(Icons.Default.AccessTime, null, tint = c.textSecondary, modifier = Modifier.size(12.dp))
                                    Spacer(Modifier.width(12.dp))
                                    DLabel(q, color = c.textPrimary, maxLines = 1, modifier = Modifier.weight(1f))
                                    Icon(Icons.AutoMirrored.Filled.CallMade, null, tint = c.textSecondary, modifier = Modifier.size(11.dp).scale(-1f, 1f))
                                }
                            }
                        }
                    }
                }
                SearchUi.Loading -> Column(
                    Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    CircularProgressIndicator(color = c.textPrimary, strokeWidth = 1.5.dp)
                    Spacer(Modifier.height(14.dp))
                    DLabel("Sintonizando YouTube…")
                }
                is SearchUi.Loaded -> {
                    val filtered = state.items.filter { activeScope.matches(it, query) }
                    if (filtered.isEmpty()) {
                        if (state.items.isNotEmpty()) {
                            EmptyState("Sin resultados para ${activeScope.title}", Icons.Default.FilterList, "Ajusta el ámbito para ver más resultados.", Modifier.fillMaxWidth().padding(top = 40.dp))
                        } else {
                            EmptyState("Sin resultados", Icons.Default.SearchOff, "Prueba una consulta distinta.", Modifier.fillMaxWidth().padding(top = 40.dp))
                        }
                    } else {
                        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 10.dp + LocalBottomInset.current)) {
                            items(filtered, key = { "${it.kind}-${it.id}" }) { item ->
                                SearchResultRow(item, toast)
                                Hairline()
                            }
                        }
                    }
                }
                is SearchUi.Failed -> EmptyState(
                    "No llegó la señal", Icons.Outlined.WarningAmber, state.message, Modifier.fillMaxWidth().padding(top = 40.dp),
                    actionTitle = "Reintentar", action = ::search,
                )
            }
        }
        toast.Host(this)
    }
}

@Composable
private fun SearchResultRow(item: MediaItem, toast: ToastState) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val c = Donda.colors
    val shows by app.library.followedShows.collectAsState()
    val isChannel = item.kind == MediaKind.CHANNEL
    val following = shows.any { it.channelId == item.id }

    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp, horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(
            Modifier.weight(1f).plainClickable {
                when {
                    isChannel && following -> nav.navigate(Destination.PodcastDetail(item.id, item.title))
                    isChannel -> nav.navigate(Destination.ArtistDetail(item.id, item.title))
                    else -> app.play(item)
                }
            },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TrackArtwork(item.artworkUrl, Modifier.size(52.dp))
            Column(Modifier.padding(start = 12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                DText(item.title, size = 16.sp, maxLines = 2)
                DLabel(if (isChannel) "Canal · Podcast" else item.channelTitle, maxLines = 1)
            }
        }
        if (isChannel) {
            OutlineButton(if (following) "Siguiendo" else "Seguir", selected = following, horizontal = 12.dp, vertical = 6.dp) {
                if (following) app.library.unfollow(item.id) else app.library.follow(PodcastShow(item.id, item.title, item.thumbnailUrl))
            }
        } else {
            IconTap(Icons.Default.PlayArrow, "Reproducir ${item.title}", iconSize = 16.dp) { app.play(item) }
            FavoriteButton(item, iconSize = 15.dp)
            TrackMenuButton(item, toast)
        }
    }
}
