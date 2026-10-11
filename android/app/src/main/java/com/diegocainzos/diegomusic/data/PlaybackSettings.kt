package com.diegocainzos.diegomusic.data

import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.json
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlin.math.abs

enum class AppThemeMode(val raw: String, val title: String) {
    BLACK("black", "Negro"),
    WHITE("white", "Blanco");

    companion object {
        /** Valores antiguos: `light`/`white` → blanco; cualquier otro (midnight, dark, system…) → negro. */
        fun migrating(raw: String?): AppThemeMode = when (raw?.lowercase()) {
            "white", "light" -> WHITE
            else -> BLACK
        }
    }
}

@Serializable
private data class RestoreState(
    val videoID: String,
    val title: String,
    val channelTitle: String,
    val thumbnailURLString: String? = null,
    val seconds: Double,
)

/** Port de `PlaybackSettings.swift`, persistido en `Preference` con las mismas claves. */
class PlaybackSettings(private val store: LibraryStore) {
    private val _themeMode = MutableStateFlow(AppThemeMode.migrating(store.preference(THEME)))
    private val _historyEnabled = MutableStateFlow(store.preference(HISTORY) == "true")
    private val _continuePlayback = MutableStateFlow(store.preference(CONTINUE) == "true")
    private val _podcastRate = MutableStateFlow(
        store.preference(RATE)?.toFloatOrNull()?.takeIf { r -> allowedPodcastRates.any { abs(it - r) < 0.001f } } ?: 1f,
    )

    val themeMode: StateFlow<AppThemeMode> = _themeMode
    val historyEnabled: StateFlow<Boolean> = _historyEnabled
    val continuePlaybackEnabled: StateFlow<Boolean> = _continuePlayback
    val podcastRate: StateFlow<Float> = _podcastRate

    val restoreState: Pair<MediaItem, Double>? =
        if (!_continuePlayback.value) null else store.preference(RESTORE)?.let { raw ->
            runCatching { json.decodeFromString(RestoreState.serializer(), raw) }.getOrNull()?.let {
                MediaItem(it.videoID, it.title, it.channelTitle, it.thumbnailURLString) to it.seconds
            }
        }

    fun setThemeMode(mode: AppThemeMode) {
        _themeMode.value = mode
        store.setPreference(mode.raw, THEME)
    }

    fun setHistoryEnabled(enabled: Boolean) {
        _historyEnabled.value = enabled
        store.setPreference(enabled.toString(), HISTORY)
    }

    fun setContinuePlaybackEnabled(enabled: Boolean) {
        _continuePlayback.value = enabled
        store.setPreference(enabled.toString(), CONTINUE)
    }

    fun cyclePodcastRate() {
        val index = allowedPodcastRates.indexOfFirst { abs(it - _podcastRate.value) < 0.001f }
        val next = if (index < 0) 1f else allowedPodcastRates[(index + 1) % allowedPodcastRates.size]
        _podcastRate.value = next
        store.setPreference(next.toString(), RATE)
    }

    /** «Continuar donde lo dejaste»: guarda la pista activa y su posición si el ajuste está activo. */
    fun persist(item: MediaItem, seconds: Double) {
        if (!_continuePlayback.value) return
        val state = RestoreState(item.id, item.title, item.channelTitle, item.artworkUrl, seconds)
        store.setPreference(json.encodeToString(RestoreState.serializer(), state), RESTORE)
    }

    // MARK: - Búsquedas recientes (`SearchHistory.swift`)

    fun recentQueries(): List<String> = store.preference(RECENT_QUERIES)?.let {
        runCatching { json.decodeFromString(ListSerializer(String.serializer()), it) }.getOrNull()
    }.orEmpty()

    fun recordQuery(query: String): List<String> {
        val normalized = query.trim()
        if (normalized.isEmpty()) return recentQueries()
        val updated = (listOf(normalized) + recentQueries().filterNot { it.equals(normalized, ignoreCase = true) }).take(10)
        store.setPreference(json.encodeToString(ListSerializer(String.serializer()), updated), RECENT_QUERIES)
        return updated
    }

    companion object {
        val allowedPodcastRates = listOf(1f, 1.25f, 1.5f, 1.75f, 2f)
        private const val THEME = "playback.themeMode"
        private const val HISTORY = "playback.historyEnabled"
        private const val CONTINUE = "playback.continuePlaybackEnabled"
        private const val RATE = "playback.podcastRate"
        private const val RESTORE = "playback.restoreState"
        private const val RECENT_QUERIES = "search.recentQueries"

        fun formatRate(rate: Float): String = when {
            abs(rate - 1f) < 0.01f -> "1×"
            abs(rate - 1.25f) < 0.01f -> "1.25×"
            abs(rate - 1.5f) < 0.01f -> "1.5×"
            abs(rate - 1.75f) < 0.01f -> "1.75×"
            abs(rate - 2f) < 0.01f -> "2×"
            else -> "%.2f×".format(rate)
        }
    }
}
