package com.diegocainzos.diegomusic.data

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** JWT del usuario en preferencias privadas de la app (respaldo desactivado en el manifiesto). */
class TokenStore(context: Context) {
    private val prefs = context.getSharedPreferences("auth", Context.MODE_PRIVATE)

    fun get(): String? = prefs.getString("accessToken", null)?.takeIf { it.isNotEmpty() }
    fun save(token: String) = prefs.edit().putString("accessToken", token).apply()
    fun delete() = prefs.edit().remove("accessToken").apply()
}

/** Equivalente de `NetworkMonitor.swift` con `ConnectivityManager`. */
class NetworkMonitor(context: Context) {
    private val manager = context.getSystemService(ConnectivityManager::class.java)
    private val _isConnected = MutableStateFlow(currentlyConnected())
    val isConnected: StateFlow<Boolean> = _isConnected

    init {
        manager.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                _isConnected.value = true
            }

            override fun onLost(network: Network) {
                _isConnected.value = currentlyConnected()
            }
        })
    }

    private fun currentlyConnected(): Boolean =
        manager.getNetworkCapabilities(manager.activeNetwork)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
}
