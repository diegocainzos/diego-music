package com.diegocainzos.diegomusic.core

import java.time.Instant

enum class MediaKind { VIDEO, CHANNEL, PLAYLIST }

data class MediaItem(
    val id: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String? = null,
    val kind: MediaKind = MediaKind.VIDEO,
    val publishedAt: Instant? = null,
    val durationSeconds: Int? = null,
) {
    /** Igual que Swift: un vídeo sin carátula usa la miniatura pública de YouTube. */
    val artworkUrl: String?
        get() = thumbnailUrl ?: if (kind == MediaKind.VIDEO && id.isNotEmpty()) "https://i.ytimg.com/vi/$id/hqdefault.jpg" else null
}

data class SearchPage(val items: List<MediaItem>, val nextPageToken: String?)

data class Artist(val id: String, val title: String, val bio: String?, val thumbnailUrl: String?)

data class ArtistDetail(
    val artist: Artist,
    val topTracks: List<MediaItem>,
    val related: List<MediaItem>,
    val albums: List<Album> = emptyList(),
)

data class Album(
    val id: String,
    val title: String,
    val channelTitle: String?,
    val thumbnailUrl: String?,
    val tracks: List<MediaItem>,
)

data class ArtistReference(val id: String, val title: String, val thumbnailUrl: String?)

data class DiscoveryFeed(val novedades: List<MediaItem>, val artistas: List<ArtistReference>)

data class PodcastShow(val channelId: String, val title: String, val thumbnailUrl: String? = null)

data class EpisodeProgressValue(
    val videoId: String,
    val channelId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val position: Double,
    val duration: Double,
    val finished: Boolean,
    val updatedAt: Long,
) {
    val mediaItem: MediaItem
        get() = MediaItem(videoId, title, channelTitle, thumbnailUrl, durationSeconds = duration.toInt())
}

data class PodcastEpisodePage(
    val episodes: List<MediaItem>,
    val hiddenShortCount: Int,
    /** Cursor de uploads para pedir episodios más antiguos; null si no hay más. */
    val nextPageToken: String? = null,
)

/** Programas fijos: IDs de canal directos, sin gastar cuota en `search.list`. */
val defaultPodcastShows = listOf(
    PodcastShow(
        "UCzQUP1qoWDoEbmsQxvdjxgQ",
        "The Joe Rogan Experience",
        "https://yt3.googleusercontent.com/ytc/AIdro_kIOv8XSayB3mVzdmGH6r6nOuncclc_QxWr7TYTXM4dFrs=s400",
    ),
    PodcastShow(
        "UCBYyJBCtCvgqA4NwtoPMwpQ",
        "The Wild Project",
        "https://yt3.googleusercontent.com/1yaek3C9bqi0LWWOfATgD067T9RuP1rcXxzzObHIYIi0sIcNiyjYo_jYzRtf0eO2UN_GfhXnIg=s400",
    ),
)

data class SavedTrack(
    val videoId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val savedAt: Long,
) {
    val mediaItem: MediaItem get() = MediaItem(videoId, title, channelTitle, thumbnailUrl)

    fun matches(query: String): Boolean {
        val q = query.trim().lowercase()
        return q.isEmpty() || title.lowercase().contains(q) || channelTitle.lowercase().contains(q)
    }
}

data class PlaylistEntry(
    val id: String,
    val videoId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val position: Int,
) {
    val mediaItem: MediaItem get() = MediaItem(videoId, title, channelTitle, thumbnailUrl)
}

data class LocalPlaylist(val id: String, val name: String, val createdAt: Long, val entries: List<PlaylistEntry>)

data class SavedAlbum(
    val id: String,
    val title: String,
    val channelTitle: String?,
    val thumbnailUrl: String?,
    val savedAt: Long,
)

/** Artista local derivado de favoritos e historial (cada artista es también un «álbum» local). */
data class LocalArtist(val name: String, val tracks: List<SavedTrack>)

data class DownloadedTrack(
    val videoId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val localFilePath: String,
    val fileSizeBytes: Long,
    val downloadedAt: Long,
    val contentType: String,
) {
    val mediaItem: MediaItem get() = MediaItem(videoId, title, channelTitle, thumbnailUrl)
}

enum class RepeatMode { OFF, ALL, ONE }

private val videoIdRegex = Regex("^[A-Za-z0-9_-]{11}$")

fun isValidVideoId(id: String): Boolean = videoIdRegex.matches(id)

fun formatTime(seconds: Double): String {
    if (!seconds.isFinite()) return "0:00"
    val total = seconds.toInt().coerceAtLeast(0)
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}

fun formatHoursMinutes(totalSeconds: Int): String {
    val h = totalSeconds / 3600
    val m = (totalSeconds % 3600) / 60
    return if (h > 0) "$h H $m MIN" else "${maxOf(1, m)} MIN"
}

fun formatRemaining(position: Double, duration: Double): String =
    formatHoursMinutes(maxOf(0.0, duration - position).toInt())

fun formatBytes(bytes: Long): String = when {
    bytes >= 1L shl 30 -> "%.1f GB".format(bytes / (1L shl 30).toDouble())
    bytes >= 1L shl 20 -> "%.1f MB".format(bytes / (1L shl 20).toDouble())
    else -> "${bytes / 1024} KB"
}
