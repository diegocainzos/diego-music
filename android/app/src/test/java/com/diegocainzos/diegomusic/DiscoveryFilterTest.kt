package com.diegocainzos.diegomusic

import com.diegocainzos.diegomusic.ui.HomeLogic
import org.junit.Assert.assertEquals
import org.junit.Test

class DiscoveryFilterTest {
    @Test
    fun filtroConTildesIgualQueSwiftYWeb() {
        listOf("Álbum completo 1990", "Disco - álbum completo", "ÁLBUM COMPLETO", "Recopilación 2020", "Los clásicos del rock", "MEGA REGGAETON - MAXI REMIXES")
            .forEach { assertEquals(it, false, HomeLogic.looksLikeSong(it)) }
        listOf("Mixed Feelings - Song", "Rosalía - Malamente", "Megan Thee Stallion - Savage", "a-ha - Take On Me (Official Video) [4K]")
            .forEach { assertEquals(it, true, HomeLogic.looksLikeSong(it)) }
    }
}
