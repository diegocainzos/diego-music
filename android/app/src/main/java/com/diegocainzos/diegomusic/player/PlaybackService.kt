package com.diegocainzos.diegomusic.player

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.CommandButton
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionResult
import com.diegocainzos.diegomusic.DiegoMusicApp
import com.diegocainzos.diegomusic.MainActivity
import com.diegocainzos.diegomusic.R
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Publica el ExoPlayer de `PlayerCoordinator` en una MediaSession: notificación, pantalla de
 * bloqueo, auriculares y Bluetooth. Música: anterior/siguiente. Episodio: −15 s / +30 s.
 */
@UnstableApi
class PlaybackService : MediaSessionService() {
    private var session: MediaSession? = null
    private lateinit var coordinator: PlayerCoordinator
    private lateinit var sessionPlayer: SessionPlayer

    private val skipBack = SessionCommand(ACTION_SKIP_BACK, Bundle.EMPTY)
    private val skipForward = SessionCommand(ACTION_SKIP_FORWARD, Bundle.EMPTY)

    override fun onCreate() {
        super.onCreate()
        coordinator = (application as DiegoMusicApp).container.player
        sessionPlayer = SessionPlayer(coordinator.player)
        val activity = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        session = MediaSession.Builder(this, sessionPlayer)
            .setSessionActivity(activity)
            .setCallback(Callback())
            .build()
        coordinator.onContextChanged = { refreshControls() }
        refreshControls()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!coordinator.player.playWhenReady || coordinator.player.mediaItemCount == 0) stopSelf()
    }

    override fun onDestroy() {
        coordinator.onContextChanged = null
        // El reproductor pertenece al coordinador: solo se libera la sesión.
        session?.release()
        session = null
        super.onDestroy()
    }

    private fun refreshControls() {
        val s = session ?: return
        s.setCustomLayout(
            if (coordinator.isPodcast) {
                listOf(
                    CommandButton.Builder().setDisplayName("−15 s").setIconResId(R.drawable.ic_replay).setSessionCommand(skipBack).build(),
                    CommandButton.Builder().setDisplayName("+30 s").setIconResId(R.drawable.ic_forward).setSessionCommand(skipForward).build(),
                )
            } else {
                emptyList()
            },
        )
        sessionPlayer.notifyCommandsChanged()
    }

    private inner class Callback : MediaSession.Callback {
        override fun onConnect(session: MediaSession, controller: MediaSession.ControllerInfo): MediaSession.ConnectionResult =
            MediaSession.ConnectionResult.AcceptedResultBuilder(session)
                .setAvailableSessionCommands(
                    MediaSession.ConnectionResult.DEFAULT_SESSION_COMMANDS.buildUpon().add(skipBack).add(skipForward).build(),
                )
                .build()

        override fun onCustomCommand(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            customCommand: SessionCommand,
            args: Bundle,
        ): ListenableFuture<SessionResult> {
            when (customCommand.customAction) {
                ACTION_SKIP_BACK -> coordinator.skip(-15.0)
                ACTION_SKIP_FORWARD -> coordinator.skip(30.0)
            }
            return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
        }
    }

    /** Redirige anterior/siguiente a la cola propia; con un episodio los oculta. */
    private inner class SessionPlayer(player: Player) : ForwardingPlayer(player) {
        private val listeners = mutableListOf<Player.Listener>()
        private val queueCommands = intArrayOf(
            COMMAND_SEEK_TO_NEXT, COMMAND_SEEK_TO_NEXT_MEDIA_ITEM, COMMAND_SEEK_TO_PREVIOUS, COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM,
        )

        override fun addListener(listener: Player.Listener) {
            listeners += listener
            super.addListener(listener)
        }

        override fun removeListener(listener: Player.Listener) {
            listeners -= listener
            super.removeListener(listener)
        }

        fun notifyCommandsChanged() {
            val commands = availableCommands
            listeners.toList().forEach { it.onAvailableCommandsChanged(commands) }
        }

        override fun getAvailableCommands(): Player.Commands {
            val builder = super.getAvailableCommands().buildUpon()
            if (coordinator.isPodcast) builder.removeAll(*queueCommands) else builder.addAll(*queueCommands)
            return builder.build()
        }

        override fun isCommandAvailable(command: Int): Boolean = availableCommands.contains(command)

        override fun play() {
            if (!coordinator.isPlaying) coordinator.togglePlayback()
        }

        override fun seekToNext() = coordinator.next()
        override fun seekToNextMediaItem() = coordinator.next()
        override fun seekToPrevious() = coordinator.previous()
        override fun seekToPreviousMediaItem() = coordinator.previous()
    }

    private companion object {
        const val ACTION_SKIP_BACK = "diegomusic.skip_back"
        const val ACTION_SKIP_FORWARD = "diegomusic.skip_forward"
    }
}
