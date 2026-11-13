package com.diegocainzos.diegomusic

import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.ui.DiscoveryChips
import com.diegocainzos.diegomusic.ui.HomeLogic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

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
        assertEquals(emptyList<String>(), HomeLogic.quickPickSeeds(emptyList(), Random(1)))
    }

    @Test
    fun variasSemillas_aSiempreSemillaMaximoTresSinRepetir() {
        val history = listOf(item("A"), item("B"), item("A"), item("C"), item("D"))
        repeat(50) { seed ->
            val seeds = HomeLogic.quickPickSeeds(history, Random(seed))
            assertEquals("A", seeds.first())
            assertEquals(3, seeds.size)
            assertEquals(seeds.size, seeds.toSet().size)
            assertTrue(seeds.all { it in setOf("A", "B", "C", "D") })
        }
        val long = (0 until 20).map { item("id$it") }
        val allowed = (0 until 10).map { "id$it" }.toSet()
        repeat(50) { seed ->
            val seeds = HomeLogic.quickPickSeeds(long, Random(seed))
            assertEquals("id0", seeds.first())
            assertEquals(3, seeds.size)
            assertTrue(seeds.toString(), seeds.all { it in allowed })
        }
    }

    @Test
    fun conHistorial_unaPistaUnaSemilla() {
        assertEquals(listOf("A"), HomeLogic.quickPickSeeds(listOf(item("A"), item("A")), Random(3)))
    }

    @Test
    fun variasSemillas_mezclaAlternaSinSemillasNiDuplicados() {
        val merged = HomeLogic.mergeMixes(
            listOf("A", "B"),
            listOf(listOf(item("a1"), item("a2"), item("A")), listOf(item("b1"), item("a1"), item("b2"))),
            20,
        )
        assertEquals(listOf("a1", "b1", "a2", "b2"), ids(merged))
    }

    @Test
    fun variasSemillas_limiteDeVeinte() {
        fun mix(p: String) = (0 until 30).map { item("$p$it") }
        assertEquals(20, HomeLogic.mergeMixes(listOf("A", "B", "C"), listOf(mix("a"), mix("b"), mix("c"))).size)
        assertEquals(listOf("a0", "a1", "a2"), ids(HomeLogic.mergeMixes(listOf("A"), listOf(mix("a")), 3)))
    }

    @Test
    fun conHistorial_mixDeASinA() {
        val merged = HomeLogic.mergeMixes(listOf("A"), listOf(listOf(item("A"), item("x"), item("y"))))
        assertEquals(listOf("x", "y"), ids(merged))
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

    @Test
    fun flujo_historialSemillasMezcla() {
        val history = listOf(item("A"), item("B"), item("A"), item("C"))
        assertEquals(listOf("A", "B", "C"), ids(HomeLogic.distinctRecent(history)))
        val seeds = HomeLogic.quickPickSeeds(history, Random(7))
        assertEquals("A", seeds.first())
        val mixes = seeds.map { s -> listOf(item("${s}1"), item("shared"), item(seeds.first()), item("${s}2")) }
        val merged = ids(HomeLogic.mergeMixes(seeds, mixes))
        seeds.forEach { assertFalse(it in merged) }
        assertEquals(merged.size, merged.toSet().size)
        assertEquals(seeds.map { "${it}1" }, merged.take(seeds.size))
        assertTrue("shared" in merged)
    }
}
