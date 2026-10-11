package com.diegocainzos.diegomusic.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.AppContainer
import com.diegocainzos.diegomusic.AuthState
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.plainClickable

@Composable
fun RootScreen(app: AppContainer) {
    val nav = remember { NavigationState() }
    val auth by app.authState.collectAsState()
    val c = Donda.colors
    CompositionLocalProvider(LocalApp provides app, LocalNav provides nav) {
        Box(Modifier.fillMaxSize().background(c.background)) {
            when (auth) {
                AuthState.Loading -> Column(
                    Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    DTitle("DiegoMusic", 14.sp, tracking = 6.sp)
                    CircularProgressIndicator(color = c.textPrimary, strokeWidth = 1.5.dp)
                }
                AuthState.Unauthenticated -> AuthGateScreen()
                is AuthState.Authenticated -> PhoneShell()
            }
        }
    }
}

/** Contenido + mini‑player flotante + barra de tres pestañas (rama iPhone de `RootView`). */
@Composable
private fun PhoneShell() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val c = Donda.colors
    val queueState by app.queue.state.collectAsState()
    var expanded by rememberSaveable { mutableStateOf(false) }
    val hasCurrent = queueState.current != null

    BackHandler(enabled = nav.canGoBack && !expanded) { nav.goBack() }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        OfflineBanner()
        Box(Modifier.weight(1f).fillMaxWidth()) {
            CompositionLocalProvider(LocalBottomInset provides if (hasCurrent) 72.dp else 0.dp) {
                key(nav.current, nav.rootResetKey) { DestinationContent(nav.current) }
            }
            if (hasCurrent) {
                MiniPlayer(
                    onExpand = { expanded = true },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(start = 12.dp, end = 12.dp, bottom = 8.dp)
                        .shadow(16.dp, RectangleShape, ambientColor = Color.Black, spotColor = Color.Black)
                        .hairlineBorder(c.outline),
                )
            }
        }
        PhoneTabBar()
    }

    if (expanded && hasCurrent) ExpandedPlayer(onDismiss = { expanded = false })
}

@Composable
private fun DestinationContent(destination: Destination) {
    when (destination) {
        Destination.Home -> HomeScreen()
        Destination.Search -> SearchScreen()
        Destination.Library -> LibraryScreen()
        is Destination.ArtistDetail -> ArtistScreen(destination.id, destination.name)
        is Destination.AlbumDetail -> AlbumScreen(destination.id)
        is Destination.PodcastDetail -> PodcastDetailScreen(destination.channelId, destination.showTitle)
    }
}

@Composable
private fun PhoneTabBar() {
    val nav = LocalNav.current
    val c = Donda.colors
    Box(
        Modifier.fillMaxWidth().background(c.background)
            .drawBehind { drawLine(c.hairline, Offset(0f, 0f), Offset(size.width, 0f), 1.dp.toPx()) }
            .navigationBarsPadding(),
    ) {
        Row(Modifier.fillMaxWidth().height(56.dp)) {
            Destination.tabs.forEach { tab ->
                Box(
                    Modifier.weight(1f).fillMaxSize().plainClickable { nav.selectTab(tab) },
                    contentAlignment = Alignment.Center,
                ) {
                    DLabel(
                        tab.title,
                        color = if (nav.current == tab) c.textPrimary else c.textSecondary,
                        size = 10.sp,
                        tracking = 3.sp,
                    )
                }
            }
        }
    }
}
