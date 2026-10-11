package com.diegocainzos.diegomusic.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.AuthState
import com.diegocainzos.diegomusic.core.formatBytes
import com.diegocainzos.diegomusic.data.AppThemeMode
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.PrimaryButton
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.minimalCard
import com.diegocainzos.diegomusic.ui.theme.plainClickable

@Composable
fun SettingsSheet(onDismiss: () -> Unit) {
    val app = LocalApp.current
    val c = Donda.colors
    val auth by app.authState.collectAsState()
    val theme by app.settings.themeMode.collectAsState()
    val historyEnabled by app.settings.historyEnabled.collectAsState()
    val continueEnabled by app.settings.continuePlaybackEnabled.collectAsState()
    val downloaded by app.downloads.downloadedTracks.collectAsState()
    var historyMessage by remember { mutableStateOf<String?>(null) }
    var confirmClear by remember { mutableStateOf(false) }

    DondaSheet(onDismiss) {
        Column(Modifier.fillMaxWidth().statusBarsPadding()) {
            Box(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 14.dp)) {
                DLabel("Cerrar", color = c.textPrimary, modifier = Modifier.plainClickable(onClick = onDismiss))
            }
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 28.dp).padding(bottom = 48.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                DTitle("Ajustes", 20.sp)

                // Cuenta
                Column(Modifier.fillMaxWidth().minimalCard(c), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    DLabel("Cuenta de usuario")
                    when (val state = auth) {
                        is AuthState.Authenticated -> Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(44.dp).hairlineBorder(c.hairline), contentAlignment = Alignment.Center) {
                                DTitle((state.user.fullName ?: state.user.email).take(1), 16.sp)
                            }
                            Column(Modifier.weight(1f).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                DText(state.user.fullName ?: "Usuario DiegoMusic", maxLines = 1)
                                DLabel(state.user.email, maxLines = 1)
                            }
                            PrimaryButton("Cerrar sesión") {
                                onDismiss()
                                app.logout()
                            }
                        }
                        AuthState.Loading -> LoadingLabel("Verificando sesión…")
                        AuthState.Unauthenticated -> DText("Conecta con tu servidor privado para sincronizar listas y preferencias.", size = 15.sp, color = c.textSecondary)
                    }
                }

                // Apariencia
                Column(Modifier.fillMaxWidth().minimalCard(c), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    DLabel("Apariencia")
                    DText("Selecciona la apariencia preferida para la interfaz de la aplicación.", size = 15.sp, color = c.textSecondary)
                    Row(Modifier.fillMaxWidth().hairlineBorder(c.outline)) {
                        AppThemeMode.entries.forEach { mode ->
                            val selected = theme == mode
                            Box(
                                Modifier.weight(1f).background(if (selected) c.textPrimary else c.background)
                                    .plainClickable { app.settings.setThemeMode(mode) }.padding(vertical = 9.dp),
                                contentAlignment = Alignment.Center,
                            ) { DLabel(mode.title, color = if (selected) c.background else c.textPrimary) }
                        }
                    }
                }

                // Audio privado
                Column(Modifier.fillMaxWidth().minimalCard(c), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    DLabel("Audio privado")
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(8.dp).background(if (app.resolverConfigured) c.textPrimary else c.textSecondary))
                        DText(
                            if (app.resolverConfigured) "Resolutor configurado" else "Resolutor pendiente de configuración",
                            modifier = Modifier.padding(start = 8.dp),
                        )
                    }
                    DText(
                        if (app.resolverConfigured) {
                            "Las canciones se resuelven en tu VPS y se reproducen de forma nativa con Media3."
                        } else {
                            "Añade AUDIO_RESOLVER_BASE_URL y AUDIO_RESOLVER_API_TOKEN a .env y vuelve a compilar la app."
                        },
                        size = 15.sp, color = c.textSecondary,
                    )
                    SettingLine("Motor", "Media3 ExoPlayer")
                    SettingLine("Vídeo embebido", "Desactivado")
                    SettingLine("URL y token", "Configuración local protegida")
                }

                // Privacidad
                Column(Modifier.fillMaxWidth().minimalCard(c), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    DLabel("Privacidad")
                    SettingLine("Biblioteca", "Solo local")
                    SettingToggle("Guardar historial local opcional", historyEnabled) { app.settings.setHistoryEnabled(it) }
                    SettingToggle("Continuar donde lo dejaste", continueEnabled) { app.settings.setContinuePlaybackEnabled(it) }
                    PrimaryButton("Borrar historial local") {
                        app.library.clearHistory()
                        historyMessage = "Historial local eliminado."
                    }
                    historyMessage?.let { DLabel(it) }
                    SettingLine("Telemetría propia", "Desactivada")
                    SettingLine("Inicio de sesión", if (auth is AuthState.Authenticated) "Activo" else "No iniciado")
                }

                // Acerca de
                Column(Modifier.fillMaxWidth().minimalCard(c), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    DLabel("Acerca de DiegoMusic")
                    DText("Proyecto privado. Usa YouTube Data API para el catálogo y un resolutor VPS privado para entregar audio temporal a Media3.", size = 15.sp)
                    DText("No es una aplicación oficial ni está afiliada con YouTube o Google. El audio no se conserva permanentemente.", size = 12.sp, color = c.textSecondary)
                }

                // Almacenamiento offline
                Column(Modifier.fillMaxWidth().minimalCard(c), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    DLabel("Almacenamiento offline")
                    SettingLine("Canciones descargadas", "${downloaded.size}")
                    SettingLine("Espacio ocupado", formatBytes(downloaded.sumOf { it.fileSizeBytes }))
                    PrimaryButton("Liberar todo el espacio", Modifier.fillMaxWidth(), icon = Icons.Default.Delete) { confirmClear = true }
                }
            }
        }
    }

    if (confirmClear) {
        ConfirmDialog(
            "Liberar todo el espacio",
            "Se borrarán ${downloaded.size} canciones del dispositivo.",
            "Eliminar todas las descargas",
            { app.downloads.removeAllDownloads() },
        ) { confirmClear = false }
    }
}

@Composable
private fun SettingLine(title: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        DText(title, modifier = Modifier.weight(1f))
        DLabel(value)
    }
}

@Composable
fun SettingToggle(title: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    val c = Donda.colors
    Row(verticalAlignment = Alignment.CenterVertically) {
        DText(title, size = 16.sp, modifier = Modifier.weight(1f))
        Switch(
            checked = checked, onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedTrackColor = c.textPrimary, checkedThumbColor = c.background,
                uncheckedTrackColor = c.background, uncheckedThumbColor = c.textSecondary, uncheckedBorderColor = c.outline,
            ),
        )
    }
}
