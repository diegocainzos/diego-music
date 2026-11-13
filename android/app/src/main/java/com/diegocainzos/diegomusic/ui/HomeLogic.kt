package com.diegocainzos.diegomusic.ui

import com.diegocainzos.diegomusic.core.MediaItem

object HomeLogic {
    /** Pistas newest-first, primera aparición por id. */
    fun distinctRecent(history: List<MediaItem>, limit: Int = 10): List<MediaItem> =
        history.distinctBy { it.id }.take(limit)

    private val notSong = Regex("""(?<![\p{L}\p{N}_])(mix|mixes|megamix|mega|best of|hits|lo mejor|top \d+|playlist|full album|[aá]lbum completo|recopilaci\p{L}*|enganchados?|cl[aá]sicos|antiguo|old school|\d+\s*(horas?|hours?)|compilation|non ?stop)(?![\p{L}\p{N}_])""")

    fun looksLikeSong(title: String): Boolean = title.count { it == ',' } < 3 && !notSong.containsMatchIn(title.lowercase())

    fun discoveryQuery(genre: String?, vibe: String?, decade: String?, country: String?): String? =
        listOfNotNull(genre, vibe, decade, country).joinToString(" ") { it.lowercase() }.ifEmpty { null }
}

object DiscoveryChips {
    val genre = listOf("Pop", "Rock", "Hip hop", "Reggaetón", "Reggae", "Electrónica", "House", "Techno", "Drum and bass", "Dubstep", "Trance", "Indie", "R&B", "Jazz", "Flamenco", "Clásica")
    val vibe = listOf("Chill", "Fiesta", "Triste", "Energía", "Romántica", "Concentración")
    val decade = listOf("70s", "80s", "90s", "2000s", "2010s", "2020s")
    val country = listOf("España", "Galicia", "México", "Argentina", "Colombia", "USA", "UK", "Brasil", "Corea", "Japón", "Francia")
}
