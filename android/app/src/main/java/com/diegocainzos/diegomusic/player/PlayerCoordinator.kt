package com.diegocainzos.diegomusic.player

import android.content.Context
import android.net.Uri
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.PlaybackQueue
import com.diegocainzos.diegomusic.core.RepeatMode
import com.diegocainzos.diegomusic.data.OfflineDownloadManager
import com.diegocainzos.diegomusic.net.AudioStreamResolving
import com.diegocainzos.diegomusic.net.ResolverException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.abs

enum class AudioPlaybackState { IDLE, RESOLVING, BUFFERING, PLAYING, PAUSED, ENDED, FAILED }

sealed interface PlaybackContext {
    object Music : PlaybackContext
    data class Podcast(val channelId: String) : PlaybackContext
}

/**
 * Port de `AudioPlayerCoordinator.swift`: un único ExoPlayer con una sola pista cargada; la cola,
 * la radio, la precarga y el progreso de episodios viven aquí. `PlaybackService` solo lo publica
 * en una MediaSession para la notificación y la pantalla de bloqueo.
 */
class PlayerCoordinator(
    context: Context,
    val queue: PlaybackQueue,
    val resolver: AudioStreamResolving,
    private val radioProvider: suspend (String) -> List<MediaItem>,
    private val scope: CoroutineScope,
) {
    val player: ExoPlayer = ExoPlayer.Builder(context)
        .setAudioAttributes(
            AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(),
            /* handleAudioFocus = */ true,
        )
        .setHandleAudioBecomingNoisy(true)
        .setWakeMode(C.WAKE_MODE_NETWORK)
        .setSeekBackIncrementMs(15_000)
        .setSeekForwardIncrementMs(30_000)
        .build()

    private val _playbackState = MutableStateFlow(AudioPlaybackState.IDLE)
    private val _currentTime = MutableStateFlow(0.0)
    private val _duration = MutableStateFlow(0.0)
    private val _errorMessage = MutableStateFlow<String?>(null)
    private val _repeatMode = MutableStateFlow(RepeatMode.OFF)
    private val _shuffleEnabled = MutableStateFlow(false)
    private val _radioSeedTitle = MutableStateFlow<String?>(null)
    private val _context = MutableStateFlow<PlaybackContext>(PlaybackContext.Music)
    private val _lastResumeSeconds = MutableStateFlow<Double?>(null)

    val playbackState: StateFlow<AudioPlaybackState> = _playbackState
    val currentTime: StateFlow<Double> = _currentTime
    val duration: StateFlow<Double> = _duration
    val errorMessage: StateFlow<String?> = _errorMessage
    val repeatMode: StateFlow<RepeatMode> = _repeatMode
    val shuffleEnabled: StateFlow<Boolean> = _shuffleEnabled
    val radioSeedTitle: StateFlow<String?> = _radioSeedTitle
    val context: StateFlow<PlaybackContext> = _context
    val lastResumeSeconds: StateFlow<Double?> = _lastResumeSeconds

    var offlineManager: OfflineDownloadManager? = null
    /** Persiste la pista activa + posición («continuar donde lo dejaste»). */
    var positionPersister: ((MediaItem, Double) -> Unit)? = null
    /** Persiste el progreso de un episodio: (episodio, canal, posición, duración). */
    var episodeProgressPersister: ((MediaItem, String, Double, Double) -> Unit)? = null
    /** Avisa a la MediaSession de que cambian los controles (música ↔ episodio). */
    var onContextChanged: (() -> Unit)? = null

    var episodeRate: Float = 1f
        set(value) {
            field = value
            applyPlaybackRate()
        }

    private var resolveJob: Job? = null
    private var recoveryJob: Job? = null
    private var prefetchJob: Job? = null
    private var warmJob: Job? = null
    private var radioJob: Job? = null
    private var loadGeneration = 0
    private var automaticRetryAvailable = true
    private var savedUpcoming: List<MediaItem> = emptyList()
    private var pendingSeekSeconds: Double? = null
    private var lastPersistedPosition = 0.0
    private var lastEpisodePersistedPosition = 0.0

    val isPlaying get() = _playbackState.value == AudioPlaybackState.PLAYING
    val isPodcast get() = _context.value is PlaybackContext.Podcast

    init {
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) = handlePlayerState(state)
            override fun onIsPlayingChanged(isPlaying: Boolean) = handleIsPlaying(isPlaying)
            override fun onPlayerError(error: PlaybackException) {
                queue.current?.let { handlePlaybackFailure(it) }
            }
        })
        scope.launch {
            while (isActive) {
                delay(500)
                tick()
            }
        }
        scope.launch { queue.state.drop(1).collect { schedulePrefetch() } }
    }

    private fun setContext(value: PlaybackContext) {
        if (_context.value == value) return
        _context.value = value
        onContextChanged?.invoke()
    }

    private val currentTargetRate: Float get() = if (isPodcast) episodeRate else 1f

    private fun applyPlaybackRate() {
        player.setPlaybackSpeed(currentTargetRate)
    }

    // MARK: - Selección

    fun select(item: MediaItem, autoRadio: Boolean = false) {
        persistEpisodePosition(throttled = false)
        _lastResumeSeconds.value = null
        setContext(PlaybackContext.Music)
        radioJob?.cancel()
        _radioSeedTitle.value = null
        savedUpcoming = emptyList()
        queue.play(item)
        applyPlaybackRate()
        load(item, autoplay = true, resetRetryBudget = true)
        if (autoRadio) startRadio(silent = true)
    }

    fun selectFromQueue(index: Int) {
        if (index !in queue.snapshot.items.indices) return
        persistEpisodePosition(throttled = false)
        _lastResumeSeconds.value = null
        setContext(PlaybackContext.Music)
        queue.selectTrack(index)
        applyPlaybackRate()
        queue.current?.let { load(it, autoplay = true, resetRetryBudget = true) }
    }

    fun playEpisode(item: MediaItem, channelId: String, resumeAt: Double?) {
        persistEpisodePosition(throttled = false)
        radioJob?.cancel()
        _radioSeedTitle.value = null
        savedUpcoming = emptyList()
        setContext(PlaybackContext.Podcast(channelId))
        queue.replaceQueue(listOf(item), 0)
        val resume = resumeAt?.takeIf { it > 0 }
        pendingSeekSeconds = resume
        _lastResumeSeconds.value = resume
        applyPlaybackRate()
        load(item, autoplay = true, resetRetryBudget = true)
    }

    /** Restaura tras reabrir la app: carga la pista y se posiciona sin reproducir. */
    fun restorePlayback(item: MediaItem, position: Double) {
        _lastResumeSeconds.value = null
        setContext(PlaybackContext.Music)
        queue.play(item)
        pendingSeekSeconds = position
        applyPlaybackRate()
        load(item, autoplay = false, resetRetryBudget = true)
    }

    // MARK: - Radio explícita

    fun startRadio(silent: Boolean = false) {
        val item = queue.current ?: return
        radioJob?.cancel()
        val snapshot = queue.snapshot
        savedUpcoming = snapshot.items.drop((snapshot.currentIndex ?: 0) + 1)
        radioJob = scope.launch {
            try {
                val items = radioProvider(item.id)
                // Respuesta obsoleta: `select` cancela el job y `selectFromQueue`/next cambian la pista actual.
                if (!isActive || queue.current?.id != item.id) return@launch
                if (items.isEmpty()) {
                    if (!silent) _errorMessage.value = RADIO_UNAVAILABLE
                    return@launch
                }
                queue.replaceUpcoming(items)
                _radioSeedTitle.value = item.title
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                if (!silent) _errorMessage.value = RADIO_UNAVAILABLE
            }
        }
    }

    fun stopRadio() {
        radioJob?.cancel()
        queue.replaceUpcoming(savedUpcoming)
        savedUpcoming = emptyList()
        _radioSeedTitle.value = null
    }

    // MARK: - Transporte

    fun togglePlayback() {
        if (isPlaying) {
            player.pause()
            return
        }
        if (player.currentMediaItem == null || player.playbackState == Player.STATE_IDLE) {
            queue.current?.let { load(it, autoplay = true, resetRetryBudget = true) }
            return
        }
        applyPlaybackRate()
        player.play()
    }

    fun retry() {
        queue.current?.let { load(it, autoplay = true, resetRetryBudget = true) }
    }

    fun next() {
        persistEpisodePosition(throttled = false)
        val item = queue.advance() ?: return
        load(item, autoplay = true, resetRetryBudget = true)
    }

    fun previous() {
        persistEpisodePosition(throttled = false)
        val item = queue.retreat()
        if (item == null) {
            seek(0.0)
            return
        }
        load(item, autoplay = true, resetRetryBudget = true)
    }

    fun toggleShuffle() {
        _shuffleEnabled.value = !_shuffleEnabled.value
        queue.setShuffle(_shuffleEnabled.value)
    }

    fun cycleRepeat() {
        _repeatMode.value = when (_repeatMode.value) {
            RepeatMode.OFF -> RepeatMode.ALL
            RepeatMode.ALL -> RepeatMode.ONE
            RepeatMode.ONE -> RepeatMode.OFF
        }
    }

    private fun handleEndOfPlayback() {
        when (_repeatMode.value) {
            RepeatMode.ONE -> queue.current?.let { load(it, autoplay = true, resetRetryBudget = true) }
            RepeatMode.ALL -> if (queue.canAdvance) next() else queue.resetToStart()?.let { load(it, autoplay = true, resetRetryBudget = true) }
            RepeatMode.OFF -> next()
        }
    }

    fun removeFromQueue(id: String) {
        val removedCurrent = queue.current?.id == id
        if (removedCurrent) persistEpisodePosition(throttled = false)
        queue.remove(id)
        if (!removedCurrent) return
        queue.current?.let { load(it, autoplay = true, resetRetryBudget = true) } ?: stop()
    }

    fun clearQueue() {
        persistEpisodePosition(throttled = false)
        queue.clear()
        stop()
    }

    fun seek(seconds: Double) {
        if (!seconds.isFinite()) return
        val d = _duration.value
        val bounded = if (d > 0) seconds.coerceIn(0.0, d) else maxOf(seconds, 0.0)
        player.seekTo((bounded * 1000).toLong())
        _currentTime.value = bounded
    }

    fun skip(by: Double) = seek(_currentTime.value + by)

    private fun stop() {
        resolveJob?.cancel()
        recoveryJob?.cancel()
        prefetchJob?.cancel()
        warmJob?.cancel()
        loadGeneration++
        persistPosition(throttled = false)
        persistEpisodePosition(throttled = false)
        _playbackState.value = AudioPlaybackState.IDLE
        player.stop()
        player.clearMediaItems()
        lastEpisodePersistedPosition = 0.0
        _currentTime.value = 0.0
        _duration.value = 0.0
        _errorMessage.value = null
    }

    // MARK: - Carga

    private fun load(item: MediaItem, autoplay: Boolean, resetRetryBudget: Boolean) {
        resolveJob?.cancel()
        if (resetRetryBudget) {
            recoveryJob?.cancel()
            automaticRetryAvailable = true
        }
        val generation = ++loadGeneration
        // El estado cambia antes de `stop()`: ExoPlayer notifica de forma síncrona.
        _playbackState.value = AudioPlaybackState.RESOLVING
        _errorMessage.value = null
        player.stop()
        player.clearMediaItems()
        _currentTime.value = 0.0
        _duration.value = 0.0
        lastEpisodePersistedPosition = 0.0

        resolveJob = scope.launch {
            try {
                // OFFLINE: si hay copia local se usa sin contactar con el resolutor.
                val uri = offlineManager?.localFile(item.id)?.let { Uri.fromFile(it) }
                    ?: Uri.parse(resolver.resolve(item.id).streamUrl)
                if (generation != loadGeneration) return@launch
                player.setMediaItem(mediaItemFor(item, uri))
                applyPlaybackRate()
                player.prepare()
                player.playWhenReady = autoplay
                _playbackState.value = AudioPlaybackState.BUFFERING
                schedulePrefetch()
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                if (generation != loadGeneration) return@launch
                _playbackState.value = AudioPlaybackState.FAILED
                _errorMessage.value = (error as? ResolverException)?.message ?: "No se pudo preparar esta canción."
            }
        }
    }

    private fun mediaItemFor(item: MediaItem, uri: Uri) = androidx.media3.common.MediaItem.Builder()
        .setMediaId(item.id)
        .setUri(uri)
        .setMediaMetadata(
            MediaMetadata.Builder()
                .setTitle(item.title)
                .setArtist(item.channelTitle)
                .setArtworkUri(item.artworkUrl?.let(Uri::parse))
                .build(),
        )
        .build()

    /** Precarga especulativa del siguiente descriptor; nunca toca la pista actual. */
    private fun schedulePrefetch() {
        prefetchJob?.cancel()
        if (player.currentMediaItem == null) return
        val snapshot = queue.snapshot
        val nextId = snapshot.currentIndex?.let { snapshot.items.getOrNull(it + 1) }?.id ?: return
        prefetchJob = scope.launch {
            delay(150)
            runCatching { resolver.resolve(nextId) }
        }
    }

    /** Precalienta en el VPS hasta 2 pistas (resolve programa su descarga). Nunca toca la cola. */
    fun warm(items: List<MediaItem>) {
        warmJob?.cancel()
        val currentId = queue.current?.id
        val ids = items.asSequence().map { it.id }.filter { it != currentId }.take(2).toList()
        if (ids.isEmpty()) return
        warmJob = scope.launch {
            for (id in ids) runCatching { resolver.resolve(id) }
        }
    }

    private fun handlePlaybackFailure(item: MediaItem) {
        if (!automaticRetryAvailable) {
            _playbackState.value = AudioPlaybackState.FAILED
            _errorMessage.value = "El reproductor no pudo abrir la pista entregada por el VPS."
            return
        }
        automaticRetryAvailable = false
        val failedGeneration = loadGeneration
        _playbackState.value = AudioPlaybackState.RESOLVING
        _errorMessage.value = null
        player.stop()
        player.clearMediaItems()
        recoveryJob?.cancel()
        recoveryJob = scope.launch {
            resolver.invalidate(item.id)
            if (failedGeneration != loadGeneration || queue.current?.id != item.id) return@launch
            load(item, autoplay = true, resetRetryBudget = false)
        }
    }

    // MARK: - Eventos del reproductor

    private fun handlePlayerState(state: Int) {
        if (player.currentMediaItem == null) return
        when (state) {
            Player.STATE_READY -> {
                updateDuration()
                pendingSeekSeconds?.let {
                    pendingSeekSeconds = null
                    seek(it)
                }
                if (!player.playWhenReady) _playbackState.value = AudioPlaybackState.PAUSED
                _errorMessage.value = null
            }
            Player.STATE_BUFFERING -> if (_playbackState.value != AudioPlaybackState.RESOLVING && player.playWhenReady) {
                _playbackState.value = AudioPlaybackState.BUFFERING
            }
            Player.STATE_ENDED -> {
                _playbackState.value = AudioPlaybackState.ENDED
                _currentTime.value = _duration.value
                persistEpisodePosition(throttled = false)
                handleEndOfPlayback()
            }
        }
    }

    private fun handleIsPlaying(playing: Boolean) {
        if (player.currentMediaItem == null) return
        if (playing) {
            _playbackState.value = AudioPlaybackState.PLAYING
            _errorMessage.value = null
            if (abs(player.playbackParameters.speed - currentTargetRate) > 0.001f) applyPlaybackRate()
            return
        }
        val current = _playbackState.value
        if (current == AudioPlaybackState.FAILED || current == AudioPlaybackState.RESOLVING || current == AudioPlaybackState.ENDED) return
        if (player.playbackState == Player.STATE_BUFFERING && player.playWhenReady) {
            _playbackState.value = AudioPlaybackState.BUFFERING
            return
        }
        _playbackState.value = AudioPlaybackState.PAUSED
        persistPosition(throttled = false)
        persistEpisodePosition(throttled = false)
    }

    private fun tick() {
        if (player.currentMediaItem == null) return
        _currentTime.value = player.currentPosition.coerceAtLeast(0) / 1000.0
        updateDuration()
        persistPosition(throttled = true)
        persistEpisodePosition(throttled = true)
    }

    private fun updateDuration() {
        val d = player.duration
        if (d != C.TIME_UNSET && d > 0) _duration.value = d / 1000.0
    }

    private fun persistPosition(throttled: Boolean) {
        val current = queue.current ?: return
        val time = _currentTime.value
        if (throttled && abs(time - lastPersistedPosition) < 5.0) return
        lastPersistedPosition = time
        positionPersister?.invoke(current, time)
    }

    private fun persistEpisodePosition(throttled: Boolean) {
        val ctx = _context.value as? PlaybackContext.Podcast ?: return
        val current = queue.current ?: return
        val time = _currentTime.value
        if (throttled && abs(time - lastEpisodePersistedPosition) < 15.0) return
        lastEpisodePersistedPosition = time
        val d = if (_duration.value > 0) _duration.value else (current.durationSeconds ?: 0).toDouble()
        episodeProgressPersister?.invoke(current, ctx.channelId, time, d)
    }

    fun clearError() {
        _errorMessage.value = null
    }

    companion object {
        const val RADIO_UNAVAILABLE = "Radio no disponible para esta pista."
    }
}
