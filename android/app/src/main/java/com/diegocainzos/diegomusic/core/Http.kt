package com.diegocainzos.diegomusic.core

import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.Json
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.net.URI
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

val json = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    coerceInputValues = true
}

val jsonMediaType = "application/json".toMediaType()

fun String.toJsonBody() = toRequestBody(jsonMediaType)

fun defaultHttpClient(): OkHttpClient = OkHttpClient.Builder()
    .connectTimeout(20, TimeUnit.SECONDS)
    .readTimeout(30, TimeUnit.SECONDS)
    .build()

/** Respuesta ya leída: el cuerpo se consume dentro de `await` para no filtrar conexiones. */
class HttpResult(val code: Int, val body: String)

suspend fun OkHttpClient.send(request: Request): HttpResult = newCall(request).await().use { response ->
    HttpResult(response.code, response.body?.string().orEmpty())
}

suspend fun Call.await(): Response = suspendCancellableCoroutine { continuation ->
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) = continuation.resume(response)
        override fun onFailure(call: Call, e: IOException) {
            if (!continuation.isCancelled) continuation.resumeWithException(e)
        }
    })
    continuation.invokeOnCancellation { runCatching { cancel() } }
}

/** Equivalente de `APIConfiguration`: claves separadas por comas para rotar ante cuota agotada. */
fun parseYouTubeKeys(raw: String): List<String> =
    if (raw.contains("$(")) emptyList() else raw.split(",").map { it.trim() }.filter { it.isNotEmpty() }

/**
 * Equivalente de `AudioResolverConfiguration`: HTTPS y sin credenciales en la URL. A diferencia de
 * iOS no hay token estático: las rutas `/v1` se autentican con el JWT del usuario, así el APK puede
 * distribuirse sin secretos del resolutor.
 */
data class ResolverConfig(val baseUrl: String) {
    companion object {
        fun parse(rawUrl: String): ResolverConfig? {
            val url = rawUrl.trim()
            if (url.isEmpty() || url.contains("$(")) return null
            val uri = runCatching { URI(url) }.getOrNull() ?: return null
            if (uri.host == null || uri.userInfo != null || uri.query != null || uri.fragment != null) return null
            if (!uri.scheme.equals("https", ignoreCase = true)) return null
            return ResolverConfig(url.trimEnd('/'))
        }
    }
}
