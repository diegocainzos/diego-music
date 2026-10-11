package com.diegocainzos.diegomusic

import android.content.ComponentName
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.diegocainzos.diegomusic.data.AppThemeMode
import com.diegocainzos.diegomusic.player.PlaybackService
import com.diegocainzos.diegomusic.ui.RootScreen
import com.diegocainzos.diegomusic.ui.theme.DondaTheme
import com.google.common.util.concurrent.ListenableFuture

class MainActivity : ComponentActivity() {
    private var controller: ListenableFuture<MediaController>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val container = (application as DiegoMusicApp).container
        setContent {
            val theme by container.settings.themeMode.collectAsState()
            LaunchedEffect(theme) {
                val style = if (theme == AppThemeMode.WHITE) {
                    SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
                } else {
                    SystemBarStyle.dark(Color.TRANSPARENT)
                }
                enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
            }
            DondaTheme(theme) { RootScreen(container) }
        }
    }

    override fun onStart() {
        super.onStart()
        // Conectar un controlador crea el servicio; Media3 lo pasa a primer plano mientras suena.
        controller = MediaController.Builder(this, SessionToken(this, ComponentName(this, PlaybackService::class.java))).buildAsync()
    }

    override fun onStop() {
        controller?.let { MediaController.releaseFuture(it) }
        controller = null
        super.onStop()
    }
}
