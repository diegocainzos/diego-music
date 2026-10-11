package com.diegocainzos.diegomusic.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import com.diegocainzos.diegomusic.AppContainer

sealed class Destination(val title: String) {
    object Home : Destination("Inicio")
    object Search : Destination("Buscar")
    object Library : Destination("Biblioteca")
    data class ArtistDetail(val id: String, val name: String) : Destination(name)
    data class AlbumDetail(val id: String, val albumTitle: String) : Destination(albumTitle)
    data class PodcastDetail(val channelId: String, val showTitle: String) : Destination(showTitle)

    companion object {
        val tabs = listOf(Home, Search, Library)
    }
}

/** Port de `NavigationState.swift`: pila de atrás/adelante y reinicio al tocar la pestaña activa. */
class NavigationState(initial: Destination = Destination.Home) {
    var current by mutableStateOf(initial)
        private set
    private val backStack = mutableListOf<Destination>()
    /** Cambia al volver a la raíz para recrear la pantalla (equivale a `rootResetTrigger`). */
    var rootResetKey by mutableIntStateOf(0)
        private set
    var canGoBack by mutableStateOf(false)
        private set

    fun goBack() {
        val previous = backStack.removeLastOrNull() ?: return
        current = previous
        canGoBack = backStack.isNotEmpty()
    }

    fun navigate(to: Destination) {
        if (to == current) return
        backStack += current
        current = to
        canGoBack = true
    }

    fun selectTab(tab: Destination) {
        if (current == tab) resetToRoot(tab) else navigate(tab)
    }

    fun resetToRoot(tab: Destination? = null) {
        backStack.clear()
        canGoBack = false
        if (tab != null) current = tab
        rootResetKey++
    }
}

val LocalApp = staticCompositionLocalOf<AppContainer> { error("AppContainer no disponible") }
val LocalNav = staticCompositionLocalOf<NavigationState> { error("NavigationState no disponible") }
