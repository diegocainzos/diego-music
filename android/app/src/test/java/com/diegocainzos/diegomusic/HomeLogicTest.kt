package com.diegocainzos.diegomusic

import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.ui.DiscoveryChips
import com.diegocainzos.diegomusic.ui.HomeLogic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HomeLogicTest {
    private fun item(id: String) = MediaItem(id, "T$id", "C")
    private fun ids(items: List<MediaItem>) = items.map { it.id }

    @Test
    fun pistasRepetidas_listaABC() {
        val history = listOf(item("A"), item("B"), item("A"), item("C"))
        assertEquals(listOf("A", "B", "C"), ids(HomeLogic.distinctRecent(history)))
    }

    @Test
    fun escuchadoHacePoco_maximoDiez() {
        val history = (0 until 15).map { item("id$it") }
        assertEquals((0 until 10).map { "id$it" }, ids(HomeLogic.distinctRecent(history)))
    }

    @Test
    fun sinHistorial_vacioYSinSemillas() {
        assertEquals(emptyList<MediaItem>(), HomeLogic.distinctRecent(emptyList()))
    }
    @Test
    fun componerLaBusqueda() {
        assertEquals("reggaetón 2010s colombia", HomeLogic.discoveryQuery("Reggaetón", null, "2010s", "Colombia"))
        assertEquals("chill", HomeLogic.discoveryQuery(null, "Chill", null, null))
    }

    @Test
    fun nadaSeleccionado_sinConsulta() {
        assertNull(HomeLogic.discoveryQuery(null, null, null, null))
    }

    @Test
    fun chipsDeDescubrimiento() {
        assertEquals(listOf("Pop", "Rock", "Hip hop", "Reggaetón", "Reggae", "Electrónica", "House", "Techno", "Drum and bass", "Dubstep", "Trance", "Indie", "R&B", "Jazz", "Flamenco", "Clásica"), DiscoveryChips.genre)
        assertEquals(listOf("Chill", "Fiesta", "Triste", "Energía", "Romántica", "Concentración"), DiscoveryChips.vibe)
        assertEquals(listOf("70s", "80s", "90s", "2000s", "2010s", "2020s"), DiscoveryChips.decade)
        assertEquals(listOf("España", "Galicia", "México", "Argentina", "Colombia", "USA", "UK", "Brasil", "Corea", "Japón", "Francia"), DiscoveryChips.country)
    }
}
