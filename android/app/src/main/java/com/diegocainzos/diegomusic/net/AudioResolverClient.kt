package com.diegocainzos.diegomusic.net

import com.diegocainzos.diegomusic.core.ResolverConfig
import com.diegocainzos.diegomusic.core.isValidVideoId
import com.diegocainzos.diegomusic.core.json
import com.diegocainzos.diegomusic.core.send
import com.diegocainzos.diegomusic.core.toJsonBody
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import okhttp3.OkHttpClient
import okhttp3.Request
import java.net.URI
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneOffset

data class AudioStreamDescriptor(val streamUrl: String, val expiresAt: Instant, val contentType: String)

/** Errores con mensaje ya saneado para mostrar al usuario. */
class ResolverException(message: String) : Exception(message)

interface AudioStreamResolving {
    suspend fun resolve(videoId: String): AudioStreamDescriptor
    suspend fun invalidate(videoId: String)
}

object UnavailableAudioResolver : AudioStreamResolving {
    override suspend fun resolve(videoId: String): AudioStreamDescriptor =
        throw ResolverException("Configura el resolutor privado en .env y vuelve a compilar la app.")

    override suspend fun invalidate(videoId: String) = Unit
}

/**
 * Port de `AudioResolverClient.swift`: caché de descriptores hasta `expiresAt − margen`
 * y una sola petición en vuelo por `videoId` (single‑flight).
 */
class AudioResolverClient(
    private val config: ResolverConfig,
    private val http: OkHttpClient,
    /** JWT del usuario: el resolutor lo acepta igual que el token estático de iOS. */
    private val token: () -> String?,
    private val expirationSafetyMarginSeconds: Long = 90,
    private val clock: () -> Instant = { Instant.now() },
) : AudioStreamResolving {
    private val mutex = Mutex()
    private val descriptors = mutableMapOf<String, AudioStreamDescriptor>()
    private val inFlight = mutableMapOf<String, Pair<Any, Deferred<AudioStreamDescriptor>>>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override suspend fun resolve(videoId: String): AudioStreamDescriptor {
        if (!isValidVideoId(videoId)) throw ResolverException("La canción no contiene un identificador de YouTube válido.")
        val token = Any()
        val deferred = mutex.withLock {
            descriptors[videoId]?.let { cached ->
                if (cached.expiresAt.epochSecond - clock().epochSecond > expirationSafetyMarginSeconds) return cached
            }
            descriptors.remove(videoId)
            inFlight[videoId]?.second ?: scope.async { requestDescriptor(videoId) }.also { inFlight[videoId] = token to it }
        }
        try {
            val descriptor = deferred.await()
            mutex.withLock {
                if (inFlight[videoId]?.first === token) {
                    inFlight.remove(videoId)
                    if (descriptor.expiresAt.epochSecond - clock().epochSecond > expirationSafetyMarginSeconds) {
                        descriptors[videoId] = descriptor
                    }
                }
            }
            return descriptor
        } catch (error: Throwable) {
            mutex.withLock { if (inFlight[videoId]?.first === token) inFlight.remove(videoId) }
            throw error
        }
    }

    override suspend fun invalidate(videoId: String) {
        mutex.withLock {
            descriptors.remove(videoId)
            inFlight.remove(videoId)?.second?.cancel()
        }
    }

    private suspend fun requestDescriptor(videoId: String): AudioStreamDescriptor {
        val request = Request.Builder()
            .url("${config.baseUrl}/v1/audio/resolve")
            .header("Authorization", "Bearer ${token() ?: throw ResolverException("Sesión no válida o expirada.")}")
            .post(json.encodeToString(ResolvePayload.serializer(), ResolvePayload(videoId)).toJsonBody())
            .build()
        val result = try {
            http.send(request)
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            throw ResolverException("El servicio privado de audio no está disponible.")
        }
        return when (result.code) {
            200 -> decodeDescriptor(result.body, clock())
            401 -> throw ResolverException("Sesión no válida o expirada.")
            422 -> throw ResolverException(
                safeServerMessage(result.body) ?: "Este contenido no ofrece una pista de audio compatible.",
            )
            in 500..599 -> throw ResolverException("El servicio privado de audio no está disponible.")
            else -> throw ResolverException("El servicio privado devolvió una respuesta no válida.")
        }
    }

    @Serializable
    private data class ResolvePayload(val videoId: String)

    @Serializable
    private data class ResolveResponse(val streamURL: String, val expiresAt: String, val contentType: String)

    @Serializable
    private data class ServerError(val detail: String? = null)

    companion object {
        private const val INVALID = "El servicio privado devolvió una respuesta no válida."

        fun decodeDescriptor(body: String, now: Instant): AudioStreamDescriptor {
            val payload = runCatching { json.decodeFromString(ResolveResponse.serializer(), body) }.getOrNull()
                ?: throw ResolverException(INVALID)
            val expiresAt = parseIsoInstant(payload.expiresAt) ?: throw ResolverException(INVALID)
            val uri = runCatching { URI(payload.streamURL) }.getOrNull()
            if (uri?.scheme?.lowercase() != "https" || uri.host == null || !expiresAt.isAfter(now) ||
                !payload.contentType.lowercase().startsWith("audio/")
            ) {
                throw ResolverException(INVALID)
            }
            return AudioStreamDescriptor(payload.streamURL, expiresAt, payload.contentType)
        }

        /** Nunca devuelve texto que pueda contener URLs o credenciales. */
        fun safeServerMessage(body: String): String? {
            val message = runCatching { json.decodeFromString(ServerError.serializer(), body).detail }.getOrNull()?.trim()
                ?: return null
            val lowered = message.lowercase()
            if (message.isEmpty() || message.length > 180 || "http://" in lowered || "https://" in lowered ||
                "bearer" in lowered || "token" in lowered
            ) {
                return null
            }
            return message
        }

        fun parseIsoInstant(value: String): Instant? =
            runCatching { OffsetDateTime.parse(value).toInstant() }.getOrNull()
                ?: runCatching { LocalDateTime.parse(value).toInstant(ZoneOffset.UTC) }.getOrNull()
    }
}
