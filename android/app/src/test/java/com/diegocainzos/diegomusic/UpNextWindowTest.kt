package com.diegocainzos.diegomusic

import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.QueueState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class UpNextWindowTest {
    private fun item(n: Int) = MediaItem("id%09d".format(n), "T$n", "C")
    private fun list(count: Int) = (1..count).map(::item)

    @Test
    fun historialLargo_muestraDeLa25ALa30() {
        val items = list(30)
        val window = QueueState(items, 24, false).upNextWindow()
        assertEquals(listOf(24, 25, 26, 27, 28, 29), window.map { it.index })
        assertEquals(items[24], window[0].value)
        assertEquals(items[29], window[5].value)
    }

    @Test
    fun historialLargo_comoMuchoActualY20Posteriores() {
        val items = list(30)
        val window = QueueState(items, 0, false).upNextWindow()
        assertEquals(21, window.size)
        assertEquals(20, window[20].index)
        assertEquals(6, QueueState(items, 0, false).upNextWindow(5).size)
    }

    @Test
    fun sinPistaActual_vistaVacia() {
        assertTrue(QueueState(list(3), null, false).upNextWindow().isEmpty())
    }

    @Test
    fun laRadioCambiaLaVista() {
        val current = item(1)
        assertEquals(listOf(current.id), QueueState(listOf(current), 0, false).upNextWindow().map { it.value.id })
        val mix = listOf(item(50), item(51))
        val window = QueueState(listOf(current) + mix, 0, false).upNextWindow()
        assertEquals(listOf(current.id, mix[0].id, mix[1].id), window.map { it.value.id })
        assertEquals(listOf(0, 1, 2), window.map { it.index })
    }

    @Test
    fun seleccionarDesdeLaVista_terceraFilaEsActualMas2() {
        val items = list(10)
        val window = QueueState(items, 3, false).upNextWindow()
        assertEquals(5, window[2].index)
        assertEquals(items[5], window[2].value)
    }
}
