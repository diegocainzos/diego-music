package com.diegocainzos.diegomusic

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.PlaybackQueue
import com.diegocainzos.diegomusic.core.ResolverConfig
import com.diegocainzos.diegomusic.core.defaultHttpClient
import com.diegocainzos.diegomusic.core.parseYouTubeKeys
import com.diegocainzos.diegomusic.data.DiegoMusicDatabase
import com.diegocainzos.diegomusic.data.LibraryStore
import com.diegocainzos.diegomusic.data.NetworkMonitor
import com.diegocainzos.diegomusic.data.OfflineDownloadManager
import com.diegocainzos.diegomusic.data.PlaybackSettings
import com.diegocainzos.diegomusic.data.TokenStore
import com.diegocainzos.diegomusic.lyrics.LrcLibProvider
import com.diegocainzos.diegomusic.net.AudioResolverClient
import com.diegocainzos.diegomusic.net.BackendClient
import com.diegocainzos.diegomusic.net.TrackPayload
import com.diegocainzos.diegomusic.net.UnavailableAudioResolver
import com.diegocainzos.diegomusic.net.UserDto
import com.diegocainzos.diegomusic.net.YouTubeDataService
import com.diegocainzos.diegomusic.player.PlayerCoordinator
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.File

sealed interface AuthState {
    object Unauthenticated : AuthState
    object Loading : AuthState
    data class Authenticated(val user: UserDto) : AuthState
}

/**
 * `X-Android-Package` y `X-Android-Cert` (SHA‑1 del certificado de firma): con ellas la clave de
 * YouTube puede restringirse a esta app en Google Cloud, aunque vaya dentro del APK.
 */
@Suppress("DEPRECATION")
private fun androidKeyHeaders(app: Application): Map<String, String> = runCatching {
    val pm = app.packageManager
    val signatures = if (android.os.Build.VERSION.SDK_INT >= 28) {
        pm.getPackageInfo(app.packageName, android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES).signingInfo?.apkContentsSigners
    } else {
        pm.getPackageInfo(app.packageName, android.content.pm.PackageManager.GET_SIGNATURES).signatures
    }
    val cert = signatures?.firstOrNull() ?: return@runCatching emptyMap()
    val sha1 = java.security.MessageDigest.getInstance("SHA-1").digest(cert.toByteArray()).joinToString("") { "%02X".format(it) }
    mapOf("X-Android-Package" to app.packageName, "X-Android-Cert" to sha1)
}.getOrDefault(emptyMap())

class DiegoMusicApp : Application(), SingletonImageLoader.Factory {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }

    override fun newImageLoader(context: PlatformContext): ImageLoader = ImageLoader.Builder(context)
        .components { add(OkHttpNetworkFetcherFactory(callFactory = { container.http })) }
        .build()
}

/** Port de `AppEnvironment.swift`: grafo de dependencias, autenticación y sincronización con el backend. */
class AppContainer(app: Application) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val http = defaultHttpClient()

    val tokens = TokenStore(app)
    private val resolverConfig = ResolverConfig.parse(BuildConfig.AUDIO_RESOLVER_BASE_URL)
    val resolverConfigured = resolverConfig != null
    val resolver = resolverConfig?.let { AudioResolverClient(it, http, token = { tokens.get() }) } ?: UnavailableAudioResolver

    private val database = DiegoMusicDatabase.create(app)
    val library = LibraryStore(database.dao())
    val settings = PlaybackSettings(library)
    val queue = PlaybackQueue()
    val youtube = YouTubeDataService(parseYouTubeKeys(BuildConfig.YOUTUBE_DATA_KEY), resolverConfig, http, { tokens.get() }, androidKeyHeaders(app))
    val backend = BackendClient(resolverConfig?.baseUrl ?: "http://localhost:8080", http)
    val network = NetworkMonitor(app)
    val lyrics = LrcLibProvider(http)
    val downloads = OfflineDownloadManager(database.dao(), File(app.filesDir, "Downloads"), http, scope)
    val player = PlayerCoordinator(app, queue, resolver, { youtube.radio(it) }, scope)

    private val _authState = MutableStateFlow<AuthState>(AuthState.Unauthenticated)
    val authState: StateFlow<AuthState> = _authState

    init {
        player.offlineManager = downloads
        player.positionPersister = { item, seconds -> settings.persist(item, seconds) }
        player.episodeProgressPersister = { item, channelId, position, duration -> library.saveProgress(item, channelId, position, duration) }
        player.episodeRate = settings.podcastRate.value
        scope.launch { settings.podcastRate.collect { player.episodeRate = it } }
        setupRealtimeSync()
        scope.launch {
            checkInitialAuthState()
            library.seedDefaultShowsIfNeeded()
        }
    }

    private val isAuthenticated get() = _authState.value is AuthState.Authenticated

    /** Ejecuta `block` con el token si hay sesión; los fallos de red del backend se ignoran como en Swift. */
    private fun withToken(block: suspend (String) -> Unit) {
        val token = tokens.get() ?: return
        if (!isAuthenticated) return
        scope.launch {
            try {
                block(token)
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
            }
        }
    }

    private fun MediaItem.payload() = TrackPayload(id, title, channelTitle, artworkUrl, durationSeconds)

    private fun setupRealtimeSync() {
        library.onFavoriteToggled = { item, isFav ->
            withToken { token -> if (isFav) backend.addFavorite(token, item.payload()) else backend.removeFavorite(token, item.id) }
        }
        library.onTrackAddedToPlaylist = { item, playlist ->
            withToken { token ->
                val remote = backend.myPlaylists(token).firstOrNull { it.name.equals(playlist.name, ignoreCase = true) }
                    ?: backend.createPlaylist(token, playlist.name)
                backend.addTrackToPlaylist(token, remote.id, item.payload())
            }
        }
        library.onTrackRemovedFromPlaylist = { entry, playlist ->
            withToken { token ->
                backend.myPlaylists(token).firstOrNull { it.name.equals(playlist.name, ignoreCase = true) }
                    ?.let { backend.removeTrackFromPlaylist(token, it.id, entry.videoId) }
            }
        }
        library.onPlaylistCreated = { playlist -> withToken { token -> backend.createPlaylist(token, playlist.name) } }
        library.onPlaylistDeleted = { playlist ->
            withToken { token ->
                backend.myPlaylists(token).firstOrNull { it.name.equals(playlist.name, ignoreCase = true) }
                    ?.let { backend.deletePlaylist(token, it.id) }
            }
        }
    }

    // MARK: - Reproducción

    fun play(item: MediaItem) {
        player.select(item, autoRadio = true)
        recordPlay(item, 0)
    }

    fun playEpisode(item: MediaItem, channelId: String) {
        val saved = library.progress(item.id)
        val resume = saved?.takeIf { !it.finished && it.position > 0 }?.position
        player.playEpisode(item, channelId, resume)
        recordPlay(item, resume?.toInt() ?: 0)
    }

    /** Sustituye la cola por `items` y empieza en `index`. */
    fun playQueue(items: List<MediaItem>, index: Int = 0) {
        if (items.isEmpty()) return
        queue.replaceQueue(items, if (index in items.indices) index else 0)
        queue.current?.let {
            player.select(it)
            recordPlay(it, 0)
        }
    }

    private fun recordPlay(item: MediaItem, playedSeconds: Int) {
        if (settings.historyEnabled.value) library.addHistory(item)
        withToken { token -> backend.recordPlay(token, item.payload(), playedSeconds) }
    }

    // MARK: - Autenticación

    private suspend fun checkInitialAuthState() {
        val token = tokens.get() ?: run {
            _authState.value = AuthState.Unauthenticated
            return
        }
        _authState.value = AuthState.Loading
        try {
            _authState.value = AuthState.Authenticated(backend.fetchMe(token))
            // El resolutor necesita el JWT: la pista anterior se restaura una vez autenticados.
            settings.restoreState?.let { (item, seconds) -> player.restorePlayback(item, seconds) }
            syncAllUserData()
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            tokens.delete()
            library.clearAllUserData()
            _authState.value = AuthState.Unauthenticated
        }
    }

    suspend fun login(email: String, password: String) = authenticate { backend.login(email, password) }

    suspend fun register(email: String, password: String, fullName: String?) = authenticate { backend.register(email, password, fullName) }

    private suspend fun authenticate(request: suspend () -> com.diegocainzos.diegomusic.net.AuthTokenResponse) {
        val response = request()
        tokens.save(response.accessToken)
        val user = backend.fetchMe(response.accessToken)
        _authState.value = AuthState.Authenticated(user)
        scope.launch { syncAllUserData() }
    }

    fun logout() {
        tokens.delete()
        library.clearAllUserData()
        _authState.value = AuthState.Unauthenticated
    }

    /** Sustituye favoritos, playlists e historial locales por los del backend (los podcasts se conservan). */
    private suspend fun syncAllUserData() {
        val token = tokens.get() ?: return
        library.clearAllUserData(keepingPodcasts = true)
        runCatching { backend.favorites(token) }.getOrNull()?.forEach { fav ->
            val t = fav.track ?: return@forEach
            library.importFavorite(t.youtubeVideoId ?: "${t.id}", t.title, t.artist?.name.orEmpty(), t.album?.coverUrl)
        }
        runCatching { backend.myPlaylists(token) }.getOrNull()?.forEach { remote ->
            val detailed = runCatching { backend.playlist(token, remote.id) }.getOrDefault(remote)
            library.importPlaylist(
                remote.name,
                detailed.tracks.map { pt ->
                    MediaItem(pt.track?.youtubeVideoId ?: "${pt.trackId}", pt.track?.title.orEmpty(), pt.track?.artist?.name.orEmpty(), pt.track?.album?.coverUrl)
                },
            )
        }
        val now = System.currentTimeMillis()
        runCatching { backend.history(token, 50) }.getOrNull()?.forEachIndexed { index, h ->
            val t = h.track ?: return@forEachIndexed
            // El backend devuelve el historial del más reciente al más antiguo: se conserva el orden.
            library.importHistory(t.youtubeVideoId ?: "${t.id}", t.title, t.artist?.name.orEmpty(), t.album?.coverUrl, now - index)
        }
        library.reload()
    }
}
