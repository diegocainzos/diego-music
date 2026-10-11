package com.diegocainzos.diegomusic.net

import com.diegocainzos.diegomusic.core.Album
import com.diegocainzos.diegomusic.core.Artist
import com.diegocainzos.diegomusic.core.ArtistDetail
import com.diegocainzos.diegomusic.core.ArtistReference
import com.diegocainzos.diegomusic.core.DiscoveryFeed
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.PodcastEpisodePage
import com.diegocainzos.diegomusic.core.ResolverConfig
import com.diegocainzos.diegomusic.core.SearchPage
import com.diegocainzos.diegomusic.core.isValidVideoId
import com.diegocainzos.diegomusic.core.json
import com.diegocainzos.diegomusic.core.send
import com.diegocainzos.diegomusic.core.toJsonBody
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.text.Normalizer
import java.time.Instant

sealed class YouTubeServiceError(message: String) : Exception(message) {
    object MissingConfiguration : YouTubeServiceError("Falta configurar YOUTUBE_DATA_KEY localmente.")
    object InvalidRequest : YouTubeServiceError("La búsqueda no es válida.")
    object Unauthorized : YouTubeServiceError("YouTube rechazó la configuración de acceso. Revisa las restricciones de la clave.")
    object QuotaExceeded : YouTubeServiceError("La cuota diaria de YouTube Data API se ha agotado en todas las claves configuradas.")
    class Server(status: Int) : YouTubeServiceError("YouTube no está disponible temporalmente.")
    object InvalidResponse : YouTubeServiceError("YouTube devolvió una respuesta que no se pudo interpretar.")
    object Network : YouTubeServiceError("No se pudo conectar con YouTube. Revisa la conexión.")
}

/** Rota a la siguiente clave cuando una agota su cuota (403 quota / 429). */
class KeyPool(private val keys: List<String>) {
    private var index = 0
    private val mutex = Mutex()
    val size get() = keys.size
    suspend fun current(): String? = mutex.withLock { keys.getOrNull(index) }
    suspend fun rotate() = mutex.withLock { if (keys.size > 1) index = (index + 1) % keys.size }
}

/** Caché en memoria con TTL; la clave se normaliza (mayúsculas, tildes y espacios). */
class TtlCache<V>(private val ttlMillis: Long, private val clock: () -> Long = System::currentTimeMillis) {
    private val storage = mutableMapOf<String, Pair<V, Long>>()

    @Synchronized
    fun get(key: String): V? {
        val k = normalizeQuery(key)
        val (value, timestamp) = storage[k] ?: return null
        if (clock() - timestamp < ttlMillis) return value
        storage.remove(k)
        return null
    }

    @Synchronized
    fun set(key: String, value: V) {
        storage[normalizeQuery(key)] = value to clock()
    }
}

private val combiningMarks = Regex("\\p{Mn}+")
private val whitespace = Regex("\\s+")

/** «Coldplay - Yellow  » → «coldplay - yellow» (igual que `SearchCache.normalize`). */
fun normalizeQuery(query: String): String =
    Normalizer.normalize(query, Normalizer.Form.NFD).replace(combiningMarks, "").lowercase().trim().replace(whitespace, " ")

private enum class Endpoint { SEARCH, SEARCH_PLAYLISTS, SEARCH_CHANNELS, CHANNELS, PLAYLISTS, PLAYLIST_ITEMS, MOST_POPULAR, CHANNEL_CONTENT, VIDEOS }

/**
 * Port de `YouTubeDataService.swift`: mismos endpoints y parámetros, rotación de claves y caída
 * al resolutor VPS. La URL lleva la clave, así que nunca se registra ni se muestra.
 */
class YouTubeDataService(
    keys: List<String>,
    private val resolver: ResolverConfig?,
    private val http: OkHttpClient,
    private val userToken: () -> String?,
    /** `X-Android-Package` / `X-Android-Cert`: permiten restringir la clave a esta app firmada. */
    private val androidHeaders: Map<String, String> = emptyMap(),
) {
    private val keyPool = KeyPool(keys)
    private val searchCache = TtlCache<SearchPage>(24 * 3600 * 1000L)
    private val podcastCache = TtlCache<PodcastEpisodePage>(3600 * 1000L)
    private var recommendationsKey = ""
    private var recommendationsItems: List<MediaItem> = emptyList()

    // MARK: - Búsqueda

    /** Vídeos musicales y, en paralelo, canales (para «SEGUIR» y el ámbito Artistas). */
    suspend fun search(query: String): SearchPage {
        searchCache.get(query)?.let { return it }
        return try {
            coroutineScope {
                val channels = async { runCatching { fetch(Endpoint.SEARCH_CHANNELS, query, max = 3, YTSearchResponse.serializer()) }.getOrNull() }
                val videos = fetch(Endpoint.SEARCH, query, max = 25, YTSearchResponse.serializer()).toPage()
                val channelItems = channels.await()?.items?.mapNotNull { it.toChannelItem() }.orEmpty()
                SearchPage(channelItems + videos.items, videos.nextPageToken)
            }.also { searchCache.set(query, it) }
        } catch (_: YouTubeServiceError.QuotaExceeded) {
            val fallback = runCatching {
                vps("/v1/search", VPSSearchResponse.serializer(), query = mapOf("q" to query))
            }.getOrNull() ?: throw YouTubeServiceError.QuotaExceeded
            SearchPage(fallback.items.map { it.mediaItem }, null).also { searchCache.set(query, it) }
        }
    }

    // MARK: - Descubrimiento

    suspend fun discover(): DiscoveryFeed = try {
        val data = fetch(Endpoint.MOST_POPULAR, max = 25, deserializer = YTVideoListResponse.serializer())
        val seen = mutableSetOf<String>()
        val artistas = data.items.mapNotNull { video ->
            val s = video.snippet ?: return@mapNotNull null
            val channelId = s.channelId?.takeIf { it.isNotEmpty() && seen.add(it) } ?: return@mapNotNull null
            ArtistReference(channelId, s.channelTitle.decodeHtmlEntities(), s.thumbnails.best())
        }
        DiscoveryFeed(
            novedades = data.items.map { it.toMediaItem() }.ifEmpty { curatedNovedades },
            artistas = artistas.ifEmpty { curatedArtistas },
        )
    } catch (error: CancellationException) {
        throw error
    } catch (_: Exception) {
        DiscoveryFeed(curatedNovedades, curatedArtistas)
    }

    // MARK: - Artista

    suspend fun artist(channelId: String): ArtistDetail {
        if (channelId.isEmpty()) throw YouTubeServiceError.InvalidRequest
        return try {
            artistFromYouTube(channelId)
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            runCatching { artistFromVps(channelId) }.getOrNull() ?: throw error
        }
    }

    private suspend fun artistFromYouTube(channelId: String): ArtistDetail = coroutineScope {
        if (channelId.startsWith("UC")) {
            val profile = runCatching {
                fetch(Endpoint.CHANNELS, channelId, max = 25, deserializer = YTChannelListResponse.serializer())
            }.getOrNull()?.items?.firstOrNull()?.toArtist()
            if (profile != null) {
                val top = async { fetch(Endpoint.SEARCH, profile.title, max = 20, deserializer = YTSearchResponse.serializer()) }
                val playlists = async { runCatching { fetch(Endpoint.PLAYLISTS, channelId, max = 15, deserializer = YTPlaylistListResponse.serializer()) }.getOrNull() }
                val albumSearch = async { runCatching { fetch(Endpoint.SEARCH_PLAYLISTS, "${profile.title} album", max = 15, deserializer = YTSearchResponse.serializer()) }.getOrNull() }
                val related = async { runCatching { fetch(Endpoint.MOST_POPULAR, max = 12, deserializer = YTVideoListResponse.serializer()) }.getOrNull() }
                val albums = (playlists.await()?.items?.map { it.toAlbum() }.orEmpty() +
                    albumSearch.await()?.items?.mapNotNull { it.toAlbum() }.orEmpty()).distinctBy { it.id }
                return@coroutineScope ArtistDetail(
                    artist = profile,
                    topTracks = top.await().items.mapNotNull { it.toMediaItem() },
                    related = related.await()?.items?.map { it.toMediaItem() }.orEmpty(),
                    albums = albums,
                )
            }
        }
        val name = channelId
        val top = async { fetch(Endpoint.SEARCH, "$name tracks", max = 20, deserializer = YTSearchResponse.serializer()) }
        val albumSearch = async { runCatching { fetch(Endpoint.SEARCH_PLAYLISTS, "$name album", max = 15, deserializer = YTSearchResponse.serializer()) }.getOrNull() }
        val related = async { runCatching { fetch(Endpoint.SEARCH, "$name radio", max = 12, deserializer = YTSearchResponse.serializer()) }.getOrNull() }
        val topTracks = top.await().items.mapNotNull { it.toMediaItem() }
        ArtistDetail(
            artist = Artist(name, name, "Canal de YouTube", topTracks.firstOrNull()?.artworkUrl),
            topTracks = topTracks,
            related = related.await()?.items?.mapNotNull { it.toMediaItem() }.orEmpty(),
            albums = albumSearch.await()?.items?.mapNotNull { it.toAlbum() }.orEmpty(),
        )
    }

    private suspend fun artistFromVps(artistId: String): ArtistDetail {
        val encoded = java.net.URLEncoder.encode(artistId, "UTF-8").replace("+", "%20")
        val dto = vps("/v1/artist/$encoded", VPSArtistDetailResponse.serializer())
        return ArtistDetail(
            Artist(dto.artist.id, dto.artist.title, dto.artist.bio, dto.artist.thumbnailURL),
            dto.topTracks.map { it.mediaItem },
            dto.related.map { it.mediaItem },
        )
    }

    // MARK: - Álbum

    suspend fun album(playlistId: String): Album {
        if (playlistId.isEmpty()) throw YouTubeServiceError.InvalidRequest
        if (playlistId.startsWith("PL") || playlistId.startsWith("OL")) {
            runCatching { fetch(Endpoint.PLAYLIST_ITEMS, playlistId, max = 25, deserializer = YTPlaylistItemsResponse.serializer()) }
                .getOrNull()?.let { data ->
                    val first = data.items.firstOrNull()?.snippet
                    return Album(
                        id = playlistId,
                        title = first?.title?.decodeHtmlEntities() ?: "Álbum / Lista",
                        channelTitle = first?.channelTitle?.decodeHtmlEntities(),
                        thumbnailUrl = first?.thumbnails?.let { it["high"] ?: it["medium"] }?.url,
                        tracks = data.items.mapNotNull { it.toMediaItem() },
                    )
                }
        }
        val tracks = fetch(Endpoint.SEARCH, "$playlistId album", max = 20, deserializer = YTSearchResponse.serializer()).items.mapNotNull { it.toMediaItem() }
        return Album(playlistId, playlistId, tracks.firstOrNull()?.channelTitle, tracks.firstOrNull()?.artworkUrl, tracks)
    }

    // MARK: - Radio y recomendaciones (resolutor)

    suspend fun radio(seedVideoId: String): List<MediaItem> {
        if (!isValidVideoId(seedVideoId)) throw YouTubeServiceError.InvalidRequest
        return vps("/v1/radio/$seedVideoId", VPSRadioResponse.serializer()).items.map { it.mediaItem }
    }

    /** Recomendaciones del LLM a partir de las últimas escuchas; se recuerdan mientras no cambien. */
    suspend fun recommendations(history: List<MediaItem>): List<MediaItem> {
        val seeds = history.take(20)
        if (seeds.isEmpty()) return emptyList()
        val key = seeds.joinToString(",") { it.id }
        if (key == recommendationsKey && recommendationsItems.isNotEmpty()) return recommendationsItems
        val body = json.encodeToString(
            VPSRecommendationsRequest.serializer(),
            VPSRecommendationsRequest(seeds.map { VPSRecommendationsRequest.Seed(it.title.take(200), it.channelTitle.take(200)) }),
        )
        val seedIds = seeds.map { it.id }.toSet()
        val items = vps("/v1/recommendations", VPSSearchResponse.serializer(), body = body).items.map { it.mediaItem }.filter { it.id !in seedIds }
        recommendationsKey = key
        recommendationsItems = items
        return items
    }

    // MARK: - Podcasts

    /** `pageToken` continúa desde una página anterior; solo la primera se cachea. */
    suspend fun podcastEpisodes(channelId: String, startToken: String? = null): PodcastEpisodePage {
        if (channelId.isEmpty()) throw YouTubeServiceError.InvalidRequest
        if (startToken == null) podcastCache.get(channelId)?.let { return it }

        val uploads = fetch(Endpoint.CHANNEL_CONTENT, channelId, deserializer = YTChannelContentDetailsResponse.serializer())
            .items.firstOrNull()?.contentDetails?.relatedPlaylists?.uploads?.takeIf { it.isNotEmpty() }
            ?: return PodcastEpisodePage(emptyList(), 0)

        // ponytail: tope fijo de 8 páginas (2 unidades de cuota cada una); «Cargar más» continúa con el cursor.
        val episodes = mutableListOf<MediaItem>()
        var hidden = 0
        var pageToken = startToken
        repeat(8) {
            val page = fetch(Endpoint.PLAYLIST_ITEMS, uploads, max = 50, pageToken = pageToken, deserializer = YTPlaylistItemsResponse.serializer())
            val withIds = page.items.mapNotNull { item ->
                (item.snippet.resourceId?.videoId ?: item.contentDetails?.videoId)?.takeIf { it.isNotEmpty() }?.let { it to item }
            }
            if (withIds.isNotEmpty()) {
                val durations = fetch(Endpoint.VIDEOS, withIds.joinToString(",") { it.first }, max = 50, deserializer = YTVideoListResponse.serializer())
                    .items.mapNotNull { v -> v.contentDetails?.duration?.let(::parseIso8601Duration)?.let { v.id to it } }.toMap()
                for ((videoId, item) in withIds) {
                    val duration = durations[videoId] ?: 0
                    if (duration < 2400) {
                        hidden++
                        continue
                    }
                    episodes += MediaItem(
                        id = videoId,
                        title = item.snippet.title.decodeHtmlEntities(),
                        channelTitle = item.snippet.channelTitle.decodeHtmlEntities(),
                        thumbnailUrl = item.snippet.thumbnails.best(),
                        publishedAt = item.snippet.publishedAt?.let { runCatching { Instant.parse(it) }.getOrNull() },
                        durationSeconds = duration,
                    )
                }
            }
            pageToken = page.nextPageToken?.takeIf { it.isNotEmpty() }
            if (episodes.size >= 30 || pageToken == null) return finish(channelId, startToken, episodes, hidden, pageToken)
        }
        return finish(channelId, startToken, episodes, hidden, pageToken)
    }

    private fun finish(channelId: String, startToken: String?, episodes: List<MediaItem>, hidden: Int, next: String?): PodcastEpisodePage {
        val page = PodcastEpisodePage(episodes.sortedByDescending { it.publishedAt ?: Instant.MIN }, hidden, next)
        if (startToken == null) podcastCache.set(channelId, page)
        return page
    }

    // MARK: - Transporte

    private fun buildUrl(endpoint: Endpoint, value: String, key: String, max: Int, pageToken: String?): HttpUrl {
        val maxResults = max.coerceIn(1, 50).toString()
        val b = HttpUrl.Builder().scheme("https").host("www.googleapis.com")
        fun q(name: String, v: String) = b.addQueryParameter(name, v)
        val query = value.trim()
        when (endpoint) {
            Endpoint.SEARCH -> {
                if (query.isEmpty()) throw YouTubeServiceError.InvalidRequest
                b.encodedPath("/youtube/v3/search")
                q("part", "snippet"); q("q", query); q("type", "video"); q("videoCategoryId", "10")
                q("videoEmbeddable", "true"); q("safeSearch", "moderate"); q("maxResults", maxResults)
            }
            Endpoint.SEARCH_PLAYLISTS -> {
                if (query.isEmpty()) throw YouTubeServiceError.InvalidRequest
                b.encodedPath("/youtube/v3/search")
                q("part", "snippet"); q("q", query); q("type", "playlist"); q("safeSearch", "moderate"); q("maxResults", maxResults)
            }
            Endpoint.SEARCH_CHANNELS -> {
                if (query.isEmpty()) throw YouTubeServiceError.InvalidRequest
                b.encodedPath("/youtube/v3/search")
                q("part", "snippet"); q("q", query); q("type", "channel"); q("maxResults", maxResults)
            }
            Endpoint.CHANNELS -> {
                b.encodedPath("/youtube/v3/channels"); q("part", "snippet"); q("id", value); q("maxResults", maxResults)
            }
            Endpoint.PLAYLISTS -> {
                b.encodedPath("/youtube/v3/playlists"); q("part", "snippet"); q("channelId", value); q("maxResults", maxResults)
            }
            Endpoint.PLAYLIST_ITEMS -> {
                b.encodedPath("/youtube/v3/playlistItems"); q("part", "snippet,contentDetails"); q("playlistId", value); q("maxResults", maxResults)
            }
            Endpoint.MOST_POPULAR -> {
                b.encodedPath("/youtube/v3/videos"); q("part", "snippet"); q("chart", "mostPopular"); q("videoCategoryId", "10"); q("maxResults", maxResults)
            }
            Endpoint.CHANNEL_CONTENT -> {
                b.encodedPath("/youtube/v3/channels"); q("part", "contentDetails"); q("id", value)
            }
            Endpoint.VIDEOS -> {
                b.encodedPath("/youtube/v3/videos"); q("part", "contentDetails,snippet"); q("id", value); q("maxResults", maxResults)
            }
        }
        q("key", key)
        if (!pageToken.isNullOrEmpty()) q("pageToken", pageToken)
        return b.build()
    }

    private suspend fun <T> fetch(
        endpoint: Endpoint,
        value: String = "",
        max: Int = 25,
        deserializer: DeserializationStrategy<T>,
        pageToken: String? = null,
    ): T {
        if (keyPool.size == 0) throw YouTubeServiceError.MissingConfiguration
        repeat(keyPool.size) {
            val key = keyPool.current() ?: throw YouTubeServiceError.MissingConfiguration
            val request = Request.Builder().url(buildUrl(endpoint, value, key, max, pageToken)).header("Accept", "application/json")
                .apply { androidHeaders.forEach { (k, v) -> header(k, v) } }
                .build()
            try {
                return run(request, deserializer)
            } catch (_: YouTubeServiceError.QuotaExceeded) {
                keyPool.rotate()
            }
        }
        throw YouTubeServiceError.QuotaExceeded
    }

    private suspend fun <T> run(request: Request, deserializer: DeserializationStrategy<T>): T {
        val result = try {
            http.send(request)
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            throw YouTubeServiceError.Network
        }
        return when (result.code) {
            in 200..299 -> runCatching { json.decodeFromString(deserializer, result.body) }.getOrNull()
                ?: throw YouTubeServiceError.InvalidResponse
            400 -> throw YouTubeServiceError.InvalidRequest
            401 -> throw YouTubeServiceError.Unauthorized
            403 -> throw if (isQuotaError(result.body)) YouTubeServiceError.QuotaExceeded else YouTubeServiceError.Unauthorized
            429 -> throw YouTubeServiceError.QuotaExceeded
            else -> throw YouTubeServiceError.Server(result.code)
        }
    }

    private fun isQuotaError(body: String): Boolean = runCatching {
        json.parseToJsonElement(body).jsonObject["error"]!!.jsonObject["errors"]!!.jsonArray.any { e ->
            val o = e.jsonObject
            o["domain"]?.jsonPrimitive?.content == "youtube.quota" ||
                o["reason"]?.jsonPrimitive?.content in setOf("quotaExceeded", "dailyLimitExceeded")
        }
    }.getOrDefault(false)

    /** GET (o POST con `body`) al resolutor; cualquier fallo se reporta como `QuotaExceeded`, igual que Swift. */
    private suspend fun <T> vps(
        path: String,
        deserializer: DeserializationStrategy<T>,
        query: Map<String, String> = emptyMap(),
        body: String? = null,
    ): T {
        val config = resolver ?: throw YouTubeServiceError.QuotaExceeded
        val url = (config.baseUrl.toHttpUrl().newBuilder().apply {
            encodedPath(path)
            query.forEach { (k, v) -> addQueryParameter(k, v) }
        }).build()
        val token = userToken() ?: throw YouTubeServiceError.QuotaExceeded
        val request = Request.Builder().url(url).header("Authorization", "Bearer $token")
            .apply { if (body != null) post(body.toJsonBody()) }
            .build()
        val result = try {
            http.send(request)
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            throw YouTubeServiceError.QuotaExceeded
        }
        if (result.code != 200) throw YouTubeServiceError.QuotaExceeded
        return json.decodeFromString(deserializer, result.body)
    }

    private companion object {
        val curatedArtistas = listOf(
            ArtistReference("Nas", "Nas", "https://i.scdn.co/image/ab6761610000e5eb51e5f8f94d9326e4f3a743a1"),
            ArtistReference("Karol G", "Karol G", "https://i.scdn.co/image/ab6761610000e5eb987515cf530e37b2d2f7ff00"),
            ArtistReference("Radiohead", "Radiohead", "https://i.scdn.co/image/ab6761610000e5eb8e03e13d987d6056d69103c8"),
            ArtistReference("Daft Punk", "Daft Punk", "https://i.scdn.co/image/ab6761610000e5eb80356bf6f8888062095f9c5d"),
            ArtistReference("Kendrick Lamar", "Kendrick Lamar", "https://i.scdn.co/image/ab6761610000e5eb437b9e2a82505b3d93ff1022"),
            ArtistReference("Taylor Swift", "Taylor Swift", "https://i.scdn.co/image/ab6761610000e5eb5a00969a4698c3132a15fbb0"),
            ArtistReference("Drake", "Drake", "https://i.scdn.co/image/ab6761610000e5eb429124237d6e641bc38615e4"),
            ArtistReference("Eminem", "Eminem", "https://i.scdn.co/image/ab6761610000e5eba00b11c129b27a88fc72f36b"),
            ArtistReference("Rosalía", "Rosalía", "https://i.scdn.co/image/ab6761610000e5ebc1b0aa4a2f89bb70d9e5b7fb"),
            ArtistReference("The Weeknd", "The Weeknd", "https://i.scdn.co/image/ab6761610000e5eb2143db297e2963690d5c0b11"),
        )
        val curatedNovedades = listOf(
            MediaItem("0WTRRLFjU10", "N.Y. State of Mind", "Nas"),
            MediaItem("AQx_KRoeddI", "Si Antes Te Hubiera Conocido", "Karol G"),
            MediaItem("XFkzRNyyg10", "Creep", "Radiohead"),
            MediaItem("5NV6Rdv1a3I", "Get Lucky", "Daft Punk ft. Pharrell Williams"),
            MediaItem("tvTRZJ-4EyI", "HUMBLE.", "Kendrick Lamar"),
            MediaItem("3tmd-ClpJxA", "Look What You Made Me Do", "Taylor Swift"),
            MediaItem("uxpDa-c-4Mc", "Hotline Bling", "Drake"),
            MediaItem("_Yhyp-_hX2s", "Lose Yourself", "Eminem"),
        )
    }
}
