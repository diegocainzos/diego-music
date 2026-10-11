package com.diegocainzos.diegomusic.lyrics

import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.json
import com.diegocainzos.diegomusic.core.send
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit
import kotlin.math.abs

data class LyricsLine(val text: String, val startTime: Double?, val endTime: Double?)

sealed interface LyricsResult {
    data class Synced(val lines: List<LyricsLine>) : LyricsResult
    data class Plain(val text: String) : LyricsResult
    object Instrumental : LyricsResult
    object NotFound : LyricsResult
}

@Serializable
data class LrcLibResponse(
    val id: Int = 0,
    val trackName: String = "",
    val artistName: String = "",
    val albumName: String? = null,
    val duration: Double = 0.0,
    val instrumental: Boolean = false,
    val plainLyrics: String? = null,
    val syncedLyrics: String? = null,
)

object LrcParser {
    private val pattern = Regex("""\[(\d{2}):(\d{2})\.(\d{2,3})]\s?(.*)""")

    /** Acepta `[mm:ss.xx]` y `[mm:ss.xxx]`; `endTime` es el inicio de la línea siguiente. */
    fun parse(lrc: String): List<LyricsLine> {
        val lines = lrc.split("\n").mapNotNull { raw ->
            val match = pattern.find(raw.trim()) ?: return@mapNotNull null
            val (mm, ss, frac, text) = match.destructured
            val fraction = if (frac.length == 3) frac.toDouble() / 1000 else frac.toDouble() / 100
            (mm.toDouble() * 60 + ss.toDouble() + fraction) to text
        }.sortedBy { it.first }
        return lines.mapIndexed { i, (time, text) -> LyricsLine(text, time, lines.getOrNull(i + 1)?.first) }
    }
}

object TrackMetadataExtractor {
    private val topicDash = Regex("""\s*-\s*Topic$""", RegexOption.IGNORE_CASE)
    private val topicSpace = Regex("""\s+Topic$""", RegexOption.IGNORE_CASE)
    private val suffix = Regex("""(VEVO|Official|Music|Channel)$""", RegexOption.IGNORE_CASE)
    private val camel = Regex("""([a-z])([A-Z])""")
    private val bracketNoise = Regex(
        """[(\[{][^)\]}]*(?:official|oficial|video|audio|lyric|letra|remaster|videoclip|visuali[sz]er|live|en\s*vivo|directo|4k|8k|hd|hq|1080p|60fps|prod\.?|feat\.?|ft\.?|with)[^)\]}]*[)\]}]""",
        RegexOption.IGNORE_CASE,
    )
    private val trailingFeat = Regex("""\s+(?:feat|ft|with)\.?\s+.*$""", RegexOption.IGNORE_CASE)
    private val spaces = Regex("""\s+""")
    private val separator = Regex("""\s+(?:[-—–|•]|//)\s+""")

    /** «Coldplay - Topic» → «Coldplay», «LadyGagaVEVO» → «Lady Gaga». */
    fun cleanChannel(channel: String): String {
        var result = channel.trim().replace(topicDash, "").replace(topicSpace, "").replace(suffix, "").trim()
        if (!result.contains(" ") && result.length > 3) result = result.replace(camel, "$1 $2")
        return result.trim()
    }

    fun cleanTitle(title: String): String = title.trim()
        .replace("\"", "").replace("'", "").replace("“", "").replace("”", "").replace("‘", "").replace("’", "")
        .replace(bracketNoise, "")
        .replace(trailingFeat, "")
        .replace(spaces, " ")
        .trim()

    /** Devuelve `(artista, canción)`; un separador en el título tiene prioridad sobre el canal. */
    fun extract(item: MediaItem): Pair<String, String> {
        val channel = cleanChannel(item.channelTitle)
        val title = cleanTitle(item.title)
        separator.find(title)?.let { match ->
            val artist = cleanTitle(cleanChannel(title.substring(0, match.range.first)))
            val track = cleanTitle(title.substring(match.range.last + 1))
            if (artist.isNotEmpty() && track.isNotEmpty()) return artist to track
        }
        return channel.ifEmpty { item.channelTitle } to title.ifEmpty { item.title }
    }
}

/** Cascada tolerante de 5 niveles contra LRCLIB, con caché de 30 min por vídeo. */
class LrcLibProvider(http: OkHttpClient) {
    private val http = http.newBuilder().callTimeout(10, TimeUnit.SECONDS).build()
    private val cache = mutableMapOf<String, Pair<LyricsResult, Long>>()

    suspend fun fetchLyrics(item: MediaItem): LyricsResult {
        cache[item.id]?.let { (result, at) -> if (System.currentTimeMillis() - at < 30 * 60_000) return result }
        val result = performFetch(item)
        cache[item.id] = result to System.currentTimeMillis()
        return result
    }

    private suspend fun performFetch(item: MediaItem): LyricsResult {
        val (artist, track) = TrackMetadataExtractor.extract(item)
        val duration = item.durationSeconds
        val stages: List<suspend () -> LrcLibResponse?> = listOf(
            { duration?.let { get(artist, track, it) } },
            { get(artist, track, null) },
            { search(mapOf("track_name" to track, "artist_name" to artist), artist, track, duration) },
            { search(mapOf("q" to "$artist $track"), artist, track, duration) },
            { if (track != item.title) search(mapOf("track_name" to track), null, track, duration) else null },
        )
        for (stage in stages) {
            val response = stage() ?: continue
            val processed = process(response)
            if (processed != LyricsResult.NotFound) return processed
        }
        return LyricsResult.NotFound
    }

    private fun process(r: LrcLibResponse): LyricsResult {
        if (r.instrumental) return LyricsResult.Instrumental
        r.syncedLyrics?.takeIf { it.isNotEmpty() }?.let { LrcParser.parse(it) }?.takeIf { it.isNotEmpty() }?.let { return LyricsResult.Synced(it) }
        r.plainLyrics?.takeIf { it.isNotEmpty() }?.let { return LyricsResult.Plain(it) }
        return LyricsResult.NotFound
    }

    private suspend fun request(path: String, params: Map<String, String>): String? = try {
        val url = "$BASE/$path".toHttpUrl().newBuilder().apply { params.forEach { (k, v) -> addQueryParameter(k, v) } }.build()
        val result = http.send(Request.Builder().url(url).header("User-Agent", USER_AGENT).build())
        result.body.takeIf { result.code == 200 }
    } catch (error: CancellationException) {
        throw error
    } catch (_: Exception) {
        null
    }

    private suspend fun get(artist: String, track: String, duration: Int?): LrcLibResponse? {
        val params = buildMap {
            put("artist_name", artist)
            put("track_name", track)
            duration?.let { put("duration", it.toString()) }
        }
        return request("get", params)?.let { runCatching { json.decodeFromString(LrcLibResponse.serializer(), it) }.getOrNull() }
    }

    private suspend fun search(params: Map<String, String>, artist: String?, track: String, duration: Int?): LrcLibResponse? {
        val results = request("search", params)
            ?.let { runCatching { json.decodeFromString(ListSerializer(LrcLibResponse.serializer()), it) }.getOrNull() }
            ?: return null
        return selectBest(results, artist, track, duration)
    }

    companion object {
        private const val BASE = "https://lrclib.net/api"
        private const val USER_AGENT = "DiegoMusic/1.0 (Android)"

        /** Puntúa sincronizadas > planas, coincidencia de título/artista y cercanía de duración (±3/±8 s; >60 s penaliza). */
        fun selectBest(results: List<LrcLibResponse>, artist: String?, track: String, duration: Int?): LrcLibResponse? {
            val t = track.lowercase()
            val a = artist?.lowercase()
            var best: Pair<LrcLibResponse, Int>? = null
            for (c in results) {
                var score = when {
                    !c.syncedLyrics.isNullOrEmpty() -> 100
                    !c.plainLyrics.isNullOrEmpty() -> 30
                    c.instrumental -> 10
                    else -> continue
                }
                val ct = c.trackName.lowercase()
                score += when {
                    ct == t -> 40
                    ct.contains(t) || t.contains(ct) -> 20
                    else -> 0
                }
                if (!a.isNullOrEmpty()) {
                    val ca = c.artistName.lowercase()
                    score += when {
                        ca == a -> 40
                        ca.contains(a) || a.contains(ca) -> 20
                        else -> 0
                    }
                }
                if (duration != null && duration > 0) {
                    val diff = abs(c.duration - duration)
                    score += when {
                        diff <= 3 -> 30
                        diff <= 8 -> 15
                        diff > 60 -> -40
                        else -> 0
                    }
                }
                if (best == null || score > best.second) best = c to score
            }
            return best?.takeIf { it.second >= 20 }?.first
        }
    }
}
