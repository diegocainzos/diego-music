package com.diegocainzos.diegomusic

import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.PlaybackQueue
import com.diegocainzos.diegomusic.core.ResolverConfig
import com.diegocainzos.diegomusic.core.formatTime
import com.diegocainzos.diegomusic.core.isValidVideoId
import com.diegocainzos.diegomusic.core.parseYouTubeKeys
import com.diegocainzos.diegomusic.data.AppThemeMode
import com.diegocainzos.diegomusic.lyrics.LrcLibProvider
import com.diegocainzos.diegomusic.lyrics.LrcLibResponse
import com.diegocainzos.diegomusic.lyrics.LrcParser
import com.diegocainzos.diegomusic.lyrics.TrackMetadataExtractor
import com.diegocainzos.diegomusic.net.AudioResolverClient
import com.diegocainzos.diegomusic.net.ResolverException
import com.diegocainzos.diegomusic.net.decodeHtmlEntities
import com.diegocainzos.diegomusic.net.normalizeQuery
import com.diegocainzos.diegomusic.net.parseIso8601Duration
import com.diegocainzos.diegomusic.ui.extractPlaylistId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class CoreLogicTest {
    private fun item(id: String) = MediaItem(id, "T$id", "C")

    @Test
    fun queueAdvanceRetreatAndEnqueueNext() {
        val q = PlaybackQueue()
        q.replaceQueue(listOf(item("a"), item("b"), item("c")), 0)
        assertTrue(q.canAdvance)
        assertFalse(q.canRetreat)
        q.enqueueNext(item("c"))
        assertEquals(listOf("a", "c", "b"), q.snapshot.items.map { it.id })
        assertEquals("c", q.advance()?.id)
        assertEquals("b", q.advance()?.id)
        assertNull(q.advance())
        assertEquals("c", q.retreat()?.id)
    }

    @Test
    fun queueReplaceUpcomingKeepsCurrent() {
        val q = PlaybackQueue()
        q.replaceQueue(listOf(item("a"), item("b"), item("c")), 1)
        q.replaceUpcoming(listOf(item("x"), item("y")))
        assertEquals(listOf("a", "b", "x", "y"), q.snapshot.items.map { it.id })
        assertEquals("b", q.current?.id)
    }

    @Test
    fun queueRemoveCurrentAndShuffleKeepsActive() {
        val q = PlaybackQueue()
        q.replaceQueue((1..10).map { item("$it") }, 3)
        q.setShuffle(true)
        assertEquals("4", q.current?.id)
        q.setShuffle(false)
        q.remove("4")
        assertEquals("5", q.current?.id)
        q.clear()
        assertNull(q.current)
    }

    @Test
    fun themeMigration() {
        assertEquals(AppThemeMode.BLACK, AppThemeMode.migrating(null))
        assertEquals(AppThemeMode.BLACK, AppThemeMode.migrating("midnight"))
        assertEquals(AppThemeMode.BLACK, AppThemeMode.migrating("system"))
        assertEquals(AppThemeMode.WHITE, AppThemeMode.migrating("light"))
        assertEquals(AppThemeMode.WHITE, AppThemeMode.migrating("WHITE"))
    }

    @Test
    fun isoDurations() {
        assertEquals(3723, parseIso8601Duration("PT1H2M3S"))
        assertEquals(2400, parseIso8601Duration("PT40M"))
        assertEquals(20, parseIso8601Duration("PT20S"))
        assertEquals(93600, parseIso8601Duration("P1DT2H"))
        assertNull(parseIso8601Duration("1H"))
    }

    @Test
    fun searchNormalization() {
        assertEquals("coldplay - yellow", normalizeQuery("  Coldplay  -   Yellow "))
        assertEquals("rosalia", normalizeQuery("Rosalía"))
    }

    @Test
    fun htmlEntities() {
        assertEquals("Rock & Roll \"Live\" it's", "Rock &amp; Roll &quot;Live&quot; it&#39;s".decodeHtmlEntities())
    }

    @Test
    fun videoIdValidation() {
        assertTrue(isValidVideoId("dQw4w9WgXcQ"))
        assertFalse(isValidVideoId("short"))
        assertFalse(isValidVideoId("https://x.y"))
        assertFalse(isValidVideoId("dQw4w9WgXc!"))
    }

    @Test
    fun metadataExtraction() {
        val (artist, track) = TrackMetadataExtractor.extract(
            MediaItem("x", "Lady Gaga - Abracadabra (Official Music Video)", "LadyGagaVEVO"),
        )
        assertEquals("Lady Gaga", artist)
        assertEquals("Abracadabra", track)
        assertEquals("Coldplay", TrackMetadataExtractor.cleanChannel("Coldplay - Topic"))
        assertEquals("Yellow", TrackMetadataExtractor.cleanTitle("Yellow (Remastered 2020) [4K] feat. Someone"))
    }

    @Test
    fun lrcParsing() {
        val lines = LrcParser.parse("[00:12.50] Hola\n[01:02.123]Adiós\nbasura")
        assertEquals(2, lines.size)
        assertEquals(12.5, lines[0].startTime!!, 0.001)
        assertEquals(62.123, lines[1].startTime!!, 0.001)
        assertEquals(62.123, lines[0].endTime!!, 0.001)
        assertNull(lines[1].endTime)
    }

    @Test
    fun lrcLibScoringPrefersSyncedAndCloseDuration() {
        val far = LrcLibResponse(trackName = "Yellow", artistName = "Coldplay", duration = 400.0, syncedLyrics = "[00:01.00] a")
        val close = LrcLibResponse(trackName = "Yellow", artistName = "Coldplay", duration = 268.0, syncedLyrics = "[00:01.00] a")
        assertEquals(close, LrcLibProvider.selectBest(listOf(far, close), "Coldplay", "Yellow", 266))
        assertNull(LrcLibProvider.selectBest(listOf(LrcLibResponse(trackName = "x", artistName = "y")), "a", "b", null))
    }

    @Test
    fun resolverConfigValidation() {
        assertNotNull(ResolverConfig.parse("https://music.example.com/"))
        assertEquals("https://music.example.com", ResolverConfig.parse("https://music.example.com/")!!.baseUrl)
        assertNull(ResolverConfig.parse("http://music.example.com"))
        assertNull(ResolverConfig.parse("https://user:pw@music.example.com"))
        assertNull(ResolverConfig.parse("https://music.example.com?x=1"))
        assertNull(ResolverConfig.parse("$(AUDIO_RESOLVER_BASE_URL)"))
        assertEquals(listOf("k1", "k2"), parseYouTubeKeys(" k1 , ,k2"))
    }

    @Test
    fun resolverDescriptorValidation() {
        val now = Instant.parse("2026-01-01T00:00:00Z")
        val ok = """{"streamURL":"https://m.example.com/v1/audio/stream/t","expiresAt":"2026-01-01T01:00:00.123+00:00","contentType":"audio/mp4","cacheStatus":"miss"}"""
        assertEquals("audio/mp4", AudioResolverClient.decodeDescriptor(ok, now).contentType)
        val insecure = ok.replace("https://", "http://")
        assertTrue(runCatching { AudioResolverClient.decodeDescriptor(insecure, now) }.exceptionOrNull() is ResolverException)
        val expired = ok.replace("2026-01-01T01:00", "2025-12-31T23:00")
        assertTrue(runCatching { AudioResolverClient.decodeDescriptor(expired, now) }.exceptionOrNull() is ResolverException)
        assertNull(AudioResolverClient.safeServerMessage("""{"detail":"Fallo en https://googlevideo.com"}"""))
        assertEquals("Vídeo no disponible.", AudioResolverClient.safeServerMessage("""{"detail":"Vídeo no disponible."}"""))
    }

    @Test
    fun playlistIdExtraction() {
        assertEquals("PL123_ab-C", extractPlaylistId("https://www.youtube.com/playlist?list=PL123_ab-C&si=x"))
        assertEquals("PLabc", extractPlaylistId("PLabc"))
        assertNull(extractPlaylistId("https://youtube.com/watch"))
    }

    @Test
    fun timeFormatting() {
        assertEquals("1:12:30", formatTime(4350.0))
        assertEquals("3:05", formatTime(185.9))
    }
}
