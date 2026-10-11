package com.diegocainzos.diegomusic.data

import com.diegocainzos.diegomusic.core.DownloadedTrack
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.await
import com.diegocainzos.diegomusic.net.AudioStreamResolving
import com.diegocainzos.diegomusic.net.ResolverException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

sealed interface DownloadState {
    object NotDownloaded : DownloadState
    object Queued : DownloadState
    data class Downloading(val progress: Double) : DownloadState
    object Downloaded : DownloadState
    data class Failed(val message: String) : DownloadState
}

/**
 * Port de `OfflineDownloadManager.swift`: cola secuencial con 2 reintentos. A diferencia de Swift,
 * escribe en streaming a un `.part` y renombra al terminar; nunca queda un archivo parcial reproducible.
 */
class OfflineDownloadManager(
    private val dao: LibraryDao,
    private val directory: File,
    private val http: OkHttpClient,
    private val scope: CoroutineScope,
) {
    private val _states = MutableStateFlow<Map<String, DownloadState>>(emptyMap())
    private val _downloaded = MutableStateFlow<List<DownloadedTrack>>(emptyList())
    val states: StateFlow<Map<String, DownloadState>> = _states
    val downloadedTracks: StateFlow<List<DownloadedTrack>> = _downloaded

    private val queue = ArrayDeque<MediaItem>()
    private var active: Job? = null

    init {
        directory.mkdirs()
        directory.listFiles { f -> f.name.endsWith(".part") }?.forEach { it.delete() }
        reload()
    }

    val totalDiskUsageBytes: Long get() = _downloaded.value.sumOf { it.fileSizeBytes }

    fun state(videoId: String): DownloadState = _states.value[videoId] ?: DownloadState.NotDownloaded

    fun isDownloaded(videoId: String) = state(videoId) == DownloadState.Downloaded

    fun localFile(videoId: String): File? {
        if (!isDownloaded(videoId)) return null
        return dao.download(videoId)?.let { File(directory, it.localFilePath) }?.takeIf { it.exists() }
    }

    fun enqueue(item: MediaItem, resolver: AudioStreamResolving) = enqueueBatch(listOf(item), resolver)

    fun enqueueBatch(items: List<MediaItem>, resolver: AudioStreamResolving) {
        for (item in items) {
            val s = state(item.id)
            if (s == DownloadState.Downloaded || s == DownloadState.Queued || s is DownloadState.Downloading) continue
            setState(item.id, DownloadState.Queued)
            if (queue.none { it.id == item.id }) queue.addLast(item)
        }
        processNext(resolver)
    }

    fun removeDownload(videoId: String) {
        dao.download(videoId)?.let { File(directory, it.localFilePath).delete() }
        dao.deleteDownload(videoId)
        _states.update { it - videoId }
        reload()
    }

    fun removeAllDownloads() {
        dao.downloads().forEach {
            File(directory, it.localFilePath).delete()
            dao.deleteDownload(it.videoId)
        }
        _states.value = emptyMap()
        reload()
    }

    private fun setState(id: String, state: DownloadState) = _states.update { it + (id to state) }

    private fun processNext(resolver: AudioStreamResolving) {
        if (active?.isActive == true) return
        val item = queue.removeFirstOrNull() ?: return
        active = scope.launch {
            perform(item, resolver)
            active = null
            processNext(resolver)
        }
    }

    private suspend fun perform(item: MediaItem, resolver: AudioStreamResolving) {
        var attempt = 0
        while (true) {
            setState(item.id, DownloadState.Downloading(0.0))
            try {
                val descriptor = resolver.resolve(item.id)
                val name = "${item.id}.m4a"
                val size = download(descriptor.streamUrl, item.id, File(directory, name))
                dao.upsertDownload(
                    DownloadedTrackRecord(item.id, item.title, item.channelTitle, item.artworkUrl, name, size, System.currentTimeMillis(), descriptor.contentType),
                )
                setState(item.id, DownloadState.Downloaded)
                reload()
                return
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                if (attempt < MAX_RETRIES) {
                    attempt++
                    delay(3_000)
                    continue
                }
                setState(item.id, DownloadState.Failed(sanitized(error)))
                return
            }
        }
    }

    private suspend fun download(url: String, videoId: String, destination: File): Long {
        val part = File(destination.parentFile, "${destination.name}.part")
        try {
            http.newCall(Request.Builder().url(url).build()).await().use { response ->
                if (!response.isSuccessful) throw IOException("HTTP ${response.code}")
                val body = response.body ?: throw IOException("Sin cuerpo")
                val expected = body.contentLength()
                withContext(Dispatchers.IO) {
                    body.byteStream().use { input ->
                        part.outputStream().use { output ->
                            val buffer = ByteArray(64 * 1024)
                            var received = 0L
                            var lastReported = 0L
                            while (true) {
                                val read = input.read(buffer)
                                if (read < 0) break
                                output.write(buffer, 0, read)
                                received += read
                                if (expected > 0 && received - lastReported >= 256 * 1024) {
                                    lastReported = received
                                    setState(videoId, DownloadState.Downloading((received.toDouble() / expected).coerceAtMost(1.0)))
                                }
                            }
                        }
                    }
                }
            }
            if (part.length() == 0L) throw IOException("Vacío")
            destination.delete()
            if (!part.renameTo(destination)) throw IOException("Renombrado")
            return destination.length()
        } finally {
            part.delete()
        }
    }

    private fun reload() {
        val records = dao.downloads()
        _downloaded.value = records.map {
            DownloadedTrack(it.videoId, it.title, it.channelTitle, it.thumbnailUrl, it.localFilePath, it.fileSizeBytes, it.downloadedAt, it.contentType)
        }
        _states.update { current ->
            current + records.filter { current[it.videoId] == null || current[it.videoId] == DownloadState.NotDownloaded }
                .associate { it.videoId to DownloadState.Downloaded }
        }
    }

    private fun sanitized(error: Exception): String = when (error) {
        is ResolverException -> "No se pudo obtener la pista de audio para descargar."
        is UnknownHostException -> "Sin conexión. Inténtalo de nuevo cuando tengas red."
        is SocketTimeoutException -> "La descarga tardó demasiado. Inténtalo de nuevo."
        is IOException -> "Error de red al descargar."
        else -> "No se pudo completar la descarga."
    }

    private companion object {
        const val MAX_RETRIES = 2
    }
}
