package com.diegocainzos.diegomusic.net

import com.diegocainzos.diegomusic.core.json
import com.diegocainzos.diegomusic.core.send
import com.diegocainzos.diegomusic.core.toJsonBody
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.FormBody
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request

@Serializable
data class AuthTokenResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("token_type") val tokenType: String = "bearer",
    @SerialName("user_id") val userId: Int = 0,
    val email: String = "",
)

@Serializable
data class UserDto(
    val id: Int,
    val email: String,
    @SerialName("full_name") val fullName: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_active") val isActive: Boolean = true,
)

@Serializable
data class BackendArtistDto(val id: Int = 0, val name: String = "")

@Serializable
data class BackendAlbumDto(val id: Int = 0, val title: String = "", @SerialName("cover_url") val coverUrl: String? = null)

@Serializable
data class BackendTrackDto(
    val id: Int = 0,
    val title: String = "",
    @SerialName("duration_seconds") val durationSeconds: Int = 0,
    @SerialName("youtube_video_id") val youtubeVideoId: String? = null,
    val artist: BackendArtistDto? = null,
    val album: BackendAlbumDto? = null,
)

@Serializable
data class BackendPlaylistTrackDto(
    @SerialName("track_id") val trackId: Int = 0,
    val order: Int = 0,
    val track: BackendTrackDto? = null,
)

@Serializable
data class BackendPlaylistDto(
    val id: Int,
    val name: String,
    val description: String? = null,
    val tracks: List<BackendPlaylistTrackDto> = emptyList(),
)

@Serializable
data class BackendFavoriteDto(val id: Int = 0, val track: BackendTrackDto? = null)

@Serializable
data class BackendPlayHistoryDto(val id: Int = 0, val track: BackendTrackDto? = null)

@Serializable
private data class RegisterPayload(val email: String, val password: String, @SerialName("full_name") val fullName: String? = null)

@Serializable
private data class CreatePlaylistPayload(val name: String, val description: String? = null, @SerialName("is_public") val isPublic: Boolean = false)

@Serializable
data class TrackPayload(
    @SerialName("youtube_video_id") val youtubeVideoId: String,
    val title: String? = null,
    @SerialName("channel_title") val channelTitle: String? = null,
    @SerialName("thumbnail_url") val thumbnailUrl: String? = null,
    @SerialName("duration_seconds") val durationSeconds: Int? = null,
)

@Serializable
private data class AddTrackPayload(
    @SerialName("youtube_video_id") val youtubeVideoId: String,
    val title: String? = null,
    @SerialName("channel_title") val channelTitle: String? = null,
    @SerialName("thumbnail_url") val thumbnailUrl: String? = null,
    @SerialName("duration_seconds") val durationSeconds: Int? = null,
    val order: Int? = null,
)

@Serializable
private data class AddFavoritePayload(
    @SerialName("entity_type") val entityType: String,
    @SerialName("youtube_video_id") val youtubeVideoId: String,
    val title: String? = null,
    @SerialName("channel_title") val channelTitle: String? = null,
    @SerialName("thumbnail_url") val thumbnailUrl: String? = null,
    @SerialName("duration_seconds") val durationSeconds: Int? = null,
)

@Serializable
private data class RecordHistoryPayload(
    @SerialName("youtube_video_id") val youtubeVideoId: String,
    val title: String? = null,
    @SerialName("channel_title") val channelTitle: String? = null,
    @SerialName("thumbnail_url") val thumbnailUrl: String? = null,
    @SerialName("duration_seconds") val durationSeconds: Int? = null,
    @SerialName("played_seconds") val playedSeconds: Double = 0.0,
    val completed: Boolean = true,
    val skipped: Boolean = false,
)

/** Errores de autenticación con mensajes saneados (`AuthError` en Swift). */
class AuthException(message: String) : Exception(message)

class BackendException(val code: Int) : Exception("Error en el servidor ($code).")

/** Cliente de `/api/v1`: autenticación, playlists, favoritos e historial. */
class BackendClient(private val baseUrl: String, private val http: OkHttpClient) {

    // MARK: - Autenticación

    suspend fun login(email: String, password: String): AuthTokenResponse {
        val request = Request.Builder().url("$baseUrl/api/v1/auth/login")
            .post(FormBody.Builder().add("username", email).add("password", password).build())
            .build()
        val result = runCatching { http.send(request) }.getOrElse { throw AuthException("No se pudo conectar con el servidor.") }
        if (result.code == 401) throw AuthException("Correo electrónico o contraseña incorrectos.")
        if (result.code !in 200..299) throw AuthException(errorDetail(result.body) ?: "Error en el servidor (${result.code}).")
        return runCatching { json.decodeFromString(AuthTokenResponse.serializer(), result.body) }
            .getOrElse { throw AuthException("Respuesta del servidor no válida.") }
    }

    suspend fun register(email: String, password: String, fullName: String?): AuthTokenResponse {
        val body = json.encodeToString(RegisterPayload.serializer(), RegisterPayload(email, password, fullName))
        val request = Request.Builder().url("$baseUrl/api/v1/auth/register").post(body.toJsonBody()).build()
        val result = runCatching { http.send(request) }.getOrElse { throw AuthException("No se pudo conectar con el servidor.") }
        if (result.code == 400) {
            val detail = errorDetail(result.body)
            if (detail?.contains("registrado") == true) throw AuthException("El correo electrónico ya está registrado.")
            throw AuthException(detail ?: "Error al registrar usuario.")
        }
        if (result.code !in 200..299) throw AuthException(errorDetail(result.body) ?: "Error en el servidor (${result.code}).")
        return runCatching { json.decodeFromString(AuthTokenResponse.serializer(), result.body) }
            .getOrElse { throw AuthException("Respuesta del servidor no válida.") }
    }

    suspend fun fetchMe(token: String): UserDto {
        val result = http.send(authorized("api/v1/auth/me", token).get().build())
        if (result.code == 401) throw AuthException("Sesión no válida o expirada.")
        if (result.code !in 200..299) throw AuthException("No se pudo obtener el perfil de usuario.")
        return runCatching { json.decodeFromString(UserDto.serializer(), result.body) }
            .getOrElse { throw AuthException("Respuesta del servidor no válida.") }
    }

    // MARK: - Playlists

    suspend fun myPlaylists(token: String) = send("GET", "api/v1/playlists/me", token, ListSerializer(BackendPlaylistDto.serializer()))

    suspend fun playlist(token: String, id: Int) = send("GET", "api/v1/playlists/$id", token, BackendPlaylistDto.serializer())

    suspend fun createPlaylist(token: String, name: String, description: String? = null) = send(
        "POST", "api/v1/playlists/", token, BackendPlaylistDto.serializer(),
        body = json.encodeToString(CreatePlaylistPayload.serializer(), CreatePlaylistPayload(name, description)),
    )

    suspend fun deletePlaylist(token: String, id: Int) = perform("DELETE", "api/v1/playlists/$id", token)

    suspend fun addTrackToPlaylist(token: String, playlistId: Int, track: TrackPayload) = send(
        "POST", "api/v1/playlists/$playlistId/tracks", token, BackendPlaylistDto.serializer(),
        body = json.encodeToString(
            AddTrackPayload.serializer(),
            AddTrackPayload(track.youtubeVideoId, track.title, track.channelTitle, track.thumbnailUrl, track.durationSeconds),
        ),
    )

    suspend fun removeTrackFromPlaylist(token: String, playlistId: Int, videoId: String) =
        perform("DELETE", "api/v1/playlists/$playlistId/tracks/$videoId", token)

    // MARK: - Favoritos

    suspend fun favorites(token: String) = send(
        "GET", "api/v1/users/me/favorites", token, ListSerializer(BackendFavoriteDto.serializer()), query = mapOf("entity_type" to "track"),
    )

    suspend fun addFavorite(token: String, track: TrackPayload) = perform(
        "POST", "api/v1/users/me/favorites", token,
        body = json.encodeToString(
            AddFavoritePayload.serializer(),
            AddFavoritePayload("track", track.youtubeVideoId, track.title, track.channelTitle, track.thumbnailUrl, track.durationSeconds),
        ),
    )

    suspend fun removeFavorite(token: String, videoId: String) = perform("DELETE", "api/v1/users/me/favorites/track/$videoId", token)

    // MARK: - Historial

    suspend fun recordPlay(token: String, track: TrackPayload, playedSeconds: Int) = perform(
        "POST", "api/v1/users/me/history", token,
        body = json.encodeToString(
            RecordHistoryPayload.serializer(),
            RecordHistoryPayload(track.youtubeVideoId, track.title, track.channelTitle, track.thumbnailUrl, track.durationSeconds, playedSeconds.toDouble()),
        ),
    )

    suspend fun history(token: String, limit: Int = 50) = send(
        "GET", "api/v1/users/me/history", token, ListSerializer(BackendPlayHistoryDto.serializer()),
        query = mapOf("limit" to "$limit", "offset" to "0"),
    )

    // MARK: - Transporte

    private fun authorized(path: String, token: String, query: Map<String, String> = emptyMap()): Request.Builder {
        val url = "$baseUrl/$path".toHttpUrl().newBuilder().apply { query.forEach { (k, v) -> addQueryParameter(k, v) } }.build()
        return Request.Builder().url(url).header("Authorization", "Bearer $token")
    }

    private suspend fun perform(method: String, path: String, token: String, query: Map<String, String> = emptyMap(), body: String? = null): String {
        val request = authorized(path, token, query).method(method, body?.toJsonBody()).build()
        val result = http.send(request)
        if (result.code !in 200..299) throw BackendException(result.code)
        return result.body
    }

    private suspend fun <T> send(
        method: String,
        path: String,
        token: String,
        deserializer: DeserializationStrategy<T>,
        query: Map<String, String> = emptyMap(),
        body: String? = null,
    ): T = json.decodeFromString(deserializer, perform(method, path, token, query, body))

    private fun errorDetail(body: String): String? = runCatching {
        (json.parseToJsonElement(body) as JsonObject)["detail"]?.jsonPrimitive?.content
    }.getOrNull()
}
