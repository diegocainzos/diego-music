package com.diegocainzos.diegomusic.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.interaction.DragInteraction
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FormatQuote
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.lyrics.LyricsLine
import com.diegocainzos.diegomusic.lyrics.LyricsResult
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.plainClickable
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest

/** Letras de la pista, incrustadas en la pestaña «LETRAS» del reproductor. */
@Composable
fun BoxScope.LyricsContent(item: MediaItem) {
    val app = LocalApp.current
    val c = Donda.colors
    var result by remember(item.id) { mutableStateOf<LyricsResult?>(null) }
    LaunchedEffect(item.id) { result = app.lyrics.fetchLyrics(item) }

    when (val r = result) {
        null -> CircularProgressIndicator(Modifier.align(Alignment.Center), color = c.textPrimary, strokeWidth = 1.5.dp)
        is LyricsResult.Synced -> SyncedLyrics(r.lines)
        is LyricsResult.Plain -> Column(Modifier.fillMaxSize()) {
            Row(Modifier.padding(horizontal = 24.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.FormatQuote, null, tint = c.textSecondary, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(6.dp))
                DLabel("Letras sin sincronización")
            }
            DText(
                r.text, size = 16.sp, lineHeight = 26.sp,
                modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 32.dp),
            )
        }
        LyricsResult.Instrumental -> Message(Icons.Default.QueueMusic, "Instrumental", null)
        LyricsResult.NotFound -> Message(Icons.Default.MusicNote, "Letra no disponible", "No se encontraron letras para esta canción")
    }
}

@Composable
private fun Message(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, subtitle: String?) {
    val c = Donda.colors
    Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)) {
        Icon(icon, null, tint = c.textSecondary, modifier = Modifier.size(42.dp))
        DTitle(title, 18.sp, align = TextAlign.Center)
        subtitle?.let { DText(it, size = 15.sp, color = c.textSecondary, align = TextAlign.Center) }
    }
}

/** Línea activa resaltada, autoscroll centrado, pausa de 3 s tras arrastrar y toque para buscar. */
@Composable
private fun SyncedLyrics(lines: List<LyricsLine>) {
    val app = LocalApp.current
    val c = Donda.colors
    val time by app.player.currentTime.collectAsState()
    val active = lines.indexOfLast { (it.startTime ?: Double.MAX_VALUE) <= time }.takeIf { it >= 0 }
    val listState = rememberLazyListState()
    var userScrolling by remember { mutableStateOf(false) }

    LaunchedEffect(listState) {
        listState.interactionSource.interactions.collectLatest { interaction ->
            when (interaction) {
                is DragInteraction.Start -> userScrolling = true
                is DragInteraction.Stop, is DragInteraction.Cancel -> {
                    delay(3_000)
                    userScrolling = false
                }
            }
        }
    }

    // La columna se fija al ancho visible (invariante `viewportWidth` de LyricsView).
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val viewport = maxHeight
        val centerOffset = with(LocalDensity.current) { (viewport * 0.4f).roundToPx() }
        LaunchedEffect(active, userScrolling) {
            if (!userScrolling) listState.animateScrollToItem((active ?: 0) + 1, -centerOffset)
        }
        LazyColumn(
            state = listState,
            modifier = Modifier.width(maxWidth).fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item { Spacer(Modifier.height(maxOf(80.dp, viewport * 0.35f))) }
            itemsIndexed(lines) { index, line ->
                if (line.text.isBlank()) {
                    Spacer(Modifier.height(24.dp))
                } else {
                    val isActive = index == active
                    val color by animateColorAsState(if (isActive) c.textPrimary else c.textSecondary, label = "line")
                    DText(
                        line.text,
                        size = if (isActive) 22.sp else 20.sp,
                        weight = if (isActive) FontWeight.Medium else FontWeight.Normal,
                        color = color,
                        lineHeight = 30.sp,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).plainClickable { line.startTime?.let(app.player::seek) },
                    )
                }
            }
            item { Spacer(Modifier.height(maxOf(80.dp, viewport * 0.35f))) }
        }
    }
}
