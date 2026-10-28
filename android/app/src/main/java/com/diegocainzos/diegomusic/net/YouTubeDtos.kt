package com.diegocainzos.diegomusic.net

import com.diegocainzos.diegomusic.core.Album
import com.diegocainzos.diegomusic.core.Artist
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.MediaKind
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

@Serializable
data class YTThumbnail(val url: String)

typealias Thumbnails = Map<String, YTThumbnail>

fun Thumbnails.best(): String? = (get("high") ?: get("medium") ?: get("default"))?.url

@Serializable
data class YTSearchResponse(val items: List<YTSearchItem> = emptyList(), val nextPageToken: String? = null)

@Serializable
data class YTSearchItem(val id: Id = Id(), val snippet: Snippet = Snippet()) {
    @Serializable
    data class Id(
        val kind: String? = null,
        val videoId: String? = null,
        val channelId: String? = null,
        val playlistId: String? = null,
    )

    @Serializable
    data class Snippet(
        val publishedAt: String? = null,
        val title: String = "",
        val description: String? = null,
        val channelId: String? = null,
        val channelTitle: String = "",
        val thumbnails: Thumbnails = emptyMap(),
    )
}

@Serializable
data class YTChannelListResponse(val items: List<YTChannel> = emptyList())

@Serializable
data class YTChannel(val id: String, val snippet: Snippet = Snippet()) {
    @Serializable
    data class Snippet(val title: String = "", val description: String? = null, val thumbnails: Thumbnails = emptyMap())
}

@Serializable
data class YTPlaylistListResponse(val items: List<YTPlaylist> = emptyList(), val nextPageToken: String? = null)

@Serializable
data class YTPlaylist(val id: String, val snippet: YTSearchItem.Snippet = YTSearchItem.Snippet())

@Serializable
data class YTVideoListResponse(val items: List<YTVideo> = emptyList(), val nextPageToken: String? = null)

@Serializable
data class YTVideo(
    val id: String,
    val snippet: YTSearchItem.Snippet? = null,
    val contentDetails: ContentDetails? = null,
) {
    @Serializable
    data class ContentDetails(val duration: String? = null)
}

@Serializable
data class YTPlaylistItemsResponse(val items: List<YTPlaylistItem> = emptyList(), val nextPageToken: String? = null)

@Serializable
data class YTPlaylistItem(
    val id: String = "",
    val snippet: Snippet = Snippet(),
    val contentDetails: ContentDetails? = null,
) {
    @Serializable
    data class Snippet(
        val publishedAt: String? = null,
        val title: String = "",
        val channelId: String? = null,
        val channelTitle: String = "",
        val thumbnails: Thumbnails = emptyMap(),
        val resourceId: ResourceId? = null,
    )

    @Serializable
    data class ResourceId(val videoId: String? = null)

    @Serializable
    data class ContentDetails(val videoId: String? = null)
}

@Serializable
data class YTChannelContentDetailsResponse(val items: List<Item> = emptyList()) {
    @Serializable
    data class Item(val id: String, val contentDetails: ContentDetails? = null)

    @Serializable
    data class ContentDetails(val relatedPlaylists: RelatedPlaylists? = null)

    @Serializable
    data class RelatedPlaylists(val uploads: String? = null)
}

// MARK: - DTOs del resolutor VPS

@Serializable
data class VPSTrack(val id: String, val title: String, val channelTitle: String, val thumbnailURL: String? = null) {
    val mediaItem get() = MediaItem(id, title, channelTitle, thumbnailURL)
}

@Serializable
data class VPSSearchResponse(val items: List<VPSTrack> = emptyList())

@Serializable
data class VPSArtistDetailResponse(
    val artist: ArtistDto,
    val topTracks: List<VPSTrack> = emptyList(),
    val related: List<VPSTrack> = emptyList(),
) {
    @Serializable
    data class ArtistDto(val id: String, val title: String, val bio: String? = null, val thumbnailURL: String? = null)
}

@Serializable
data class VPSRadioResponse(val items: List<Item> = emptyList()) {
    @Serializable
    data class Item(
        val id: String,
        val title: String,
        val channel: String,
        @SerialName("duration_seconds") val durationSeconds: Int? = null,
    ) {
        val mediaItem get() = MediaItem(id, title, channel, durationSeconds = durationSeconds)
    }
}

// MARK: - Mapper (YouTubeMapper.swift)

private fun parseInstant(value: String?): Instant? = value?.let { runCatching { Instant.parse(it) }.getOrNull() }

private fun mediaItem(id: String, title: String, channel: String, thumbnails: Thumbnails, publishedAt: String?) =
    MediaItem(
        id = id,
        title = title.decodeHtmlEntities(),
        channelTitle = channel.decodeHtmlEntities(),
        thumbnailUrl = thumbnails.best(),
        publishedAt = parseInstant(publishedAt),
    )

fun YTSearchResponse.toPage() = com.diegocainzos.diegomusic.core.SearchPage(items.mapNotNull { it.toMediaItem() }, nextPageToken)

fun YTSearchItem.toMediaItem(): MediaItem? {
    val id = id.videoId?.takeIf { it.isNotEmpty() } ?: return null
    return mediaItem(id, snippet.title, snippet.channelTitle, snippet.thumbnails, snippet.publishedAt)
}

fun YTSearchItem.toChannelItem(): MediaItem? {
    val channelId = (id.channelId ?: snippet.channelId)?.takeIf { it.isNotEmpty() } ?: return null
    return MediaItem(
        id = channelId,
        title = snippet.title.decodeHtmlEntities(),
        channelTitle = snippet.channelTitle.decodeHtmlEntities(),
        thumbnailUrl = snippet.thumbnails.best(),
        kind = MediaKind.CHANNEL,
    )
}

fun YTSearchItem.toAlbum(): Album? {
    val playlistId = id.playlistId?.takeIf { it.isNotEmpty() } ?: return null
    return Album(playlistId, snippet.title.decodeHtmlEntities(), snippet.channelTitle.decodeHtmlEntities(), snippet.thumbnails.best(), emptyList())
}

fun YTVideo.toMediaItem(): MediaItem {
    val s = snippet ?: YTSearchItem.Snippet()
    return mediaItem(id, s.title, s.channelTitle, s.thumbnails, s.publishedAt)
}

fun YTPlaylistItem.toMediaItem(): MediaItem? {
    val videoId = snippet.resourceId?.videoId?.takeIf { it.isNotEmpty() } ?: return null
    return mediaItem(videoId, snippet.title, snippet.channelTitle, snippet.thumbnails, snippet.publishedAt)
}

fun YTChannel.toArtist() = Artist(id, snippet.title.decodeHtmlEntities(), snippet.description?.decodeHtmlEntities(), snippet.thumbnails.best())

fun YTPlaylist.toAlbum() = Album(id, snippet.title.decodeHtmlEntities(), snippet.channelTitle.decodeHtmlEntities(), snippet.thumbnails.best(), emptyList())

private val numericEntity = Regex("&#(x?[0-9A-Fa-f]+);")

/** YouTube devuelve títulos con entidades HTML (`&amp;`, `&#39;`…). */
fun String.decodeHtmlEntities(): String {
    if (!contains('&')) return this
    return numericEntity.replace(this) { match ->
        val raw = match.groupValues[1]
        val code = if (raw.startsWith("x") || raw.startsWith("X")) raw.drop(1).toIntOrNull(16) else raw.toIntOrNull()
        code?.let { String(Character.toChars(it)) } ?: match.value
    }
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
}

/** Parsea una duración ISO 8601 (`PT1H2M3S`, `PT40M`, `P1DT2H`) a segundos. */
fun parseIso8601Duration(value: String): Int? {
    if (!value.startsWith("P")) return null
    val parts = value.split("T")
    val datePart = parts[0].drop(1)
    val timePart = parts.getOrElse(1) { "" }
    var total = datePart.substringBefore("D", "").toIntOrNull()?.times(86_400) ?: 0
    var digits = ""
    for (c in timePart) {
        when {
            c.isDigit() -> digits += c
            c == 'H' -> { total += (digits.toIntOrNull() ?: 0) * 3600; digits = "" }
            c == 'M' -> { total += (digits.toIntOrNull() ?: 0) * 60; digits = "" }
            c == 'S' -> { total += digits.toIntOrNull() ?: 0; digits = "" }
        }
    }
    return total.takeIf { it >= 0 }
}
