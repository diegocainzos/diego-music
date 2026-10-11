package com.diegocainzos.diegomusic.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Cancel
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.diegocainzos.diegomusic.ui.theme.DLabel
import com.diegocainzos.diegomusic.ui.theme.DText
import com.diegocainzos.diegomusic.ui.theme.DTitle
import com.diegocainzos.diegomusic.ui.theme.Donda
import com.diegocainzos.diegomusic.ui.theme.PrimaryButton
import com.diegocainzos.diegomusic.ui.theme.hairlineBorder
import com.diegocainzos.diegomusic.ui.theme.minimalCard
import com.diegocainzos.diegomusic.ui.theme.plainClickable
import kotlinx.coroutines.launch

/** Campo de texto Donda: borde `outline`, alto mínimo 40, sin radio. */
@Composable
fun DField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    secure: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Done,
    onSubmit: () -> Unit = {},
    mono: Boolean = false,
) {
    val c = Donda.colors
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = TextStyle(color = c.textPrimary, fontSize = if (mono) 13.sp else 16.sp, fontFamily = if (mono) Donda.mono else null),
        cursorBrush = SolidColor(c.textPrimary),
        visualTransformation = if (secure) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(
            keyboardType = if (secure) KeyboardType.Password else keyboardType,
            imeAction = imeAction,
            capitalization = KeyboardCapitalization.None,
            autoCorrectEnabled = false,
        ),
        keyboardActions = KeyboardActions(onAny = { onSubmit() }),
        modifier = modifier,
        decorationBox = { inner ->
            Box(
                Modifier.fillMaxWidth().heightIn(min = 40.dp).background(c.background).hairlineBorder(c.outline).padding(horizontal = 10.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (value.isEmpty()) {
                    if (mono) DLabel(placeholder) else DText(placeholder, size = 16.sp, color = c.textSecondary, maxLines = 1)
                }
                inner()
            }
        },
    )
}

@Composable
private fun LabeledField(label: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        DLabel(label)
        content()
    }
}

@Composable
private fun Requirement(ok: Boolean, text: String, okIcon: ImageVector = Icons.Outlined.CheckCircle, badIcon: ImageVector = Icons.Outlined.Circle) {
    val c = Donda.colors
    val color = if (ok) c.textPrimary else c.textSecondary
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(if (ok) okIcon else badIcon, null, tint = color, modifier = Modifier.size(11.dp))
        Spacer(Modifier.width(6.dp))
        DText(text, size = 11.sp, color = color)
    }
}

@Composable
private fun ErrorLine(message: String) {
    val c = Donda.colors
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 2.dp)) {
        Icon(Icons.Outlined.WarningAmber, null, tint = c.textSecondary, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(6.dp))
        DText(message, size = 12.sp, color = c.textSecondary)
    }
}

/** Puerta de autenticación obligatoria: no se puede cerrar ni omitir. */
@Composable
fun AuthGateScreen() {
    val c = Donda.colors
    var registerTab by rememberSaveable { mutableStateOf(false) }
    Column(
        Modifier.fillMaxSize().statusBarsPadding().imePadding().verticalScroll(rememberScrollState()).padding(bottom = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(28.dp),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            DTitle("DiegoMusic", 24.sp, modifier = Modifier.padding(top = 40.dp))
            DText(
                "Inicia sesión para sincronizar tus playlists, favoritos y música.",
                size = 15.sp, color = c.textSecondary, align = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp),
            )
        }
        Row(Modifier.padding(horizontal = 32.dp).fillMaxWidth().hairlineBorder(c.outline)) {
            listOf(false to "Iniciar sesión", true to "Crear cuenta").forEach { (isRegister, title) ->
                val selected = registerTab == isRegister
                Box(
                    Modifier.weight(1f).background(if (selected) c.textPrimary else c.background)
                        .plainClickable { registerTab = isRegister }.padding(vertical = 9.dp),
                    contentAlignment = Alignment.Center,
                ) { DLabel(title, color = if (selected) c.background else c.textPrimary) }
            }
        }
        Column(Modifier.padding(horizontal = 24.dp).fillMaxWidth().minimalCard(c), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (registerTab) RegisterForm() else LoginForm()
        }
    }
}

@Composable
private fun LoginForm() {
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    var busy by rememberSaveable { mutableStateOf(false) }
    val canSubmit = email.isNotBlank() && password.isNotEmpty() && !busy

    fun submit() {
        if (!canSubmit) return
        busy = true
        error = null
        scope.launch {
            try {
                app.login(email.trim(), password)
            } catch (e: Exception) {
                error = e.message ?: "No se pudo iniciar sesión."
            }
            busy = false
        }
    }

    LabeledField("Correo electrónico") {
        DField(email, { email = it }, "usuario@ejemplo.com", keyboardType = KeyboardType.Email, imeAction = ImeAction.Next)
    }
    LabeledField("Contraseña") {
        DField(password, { password = it }, "••••••••", secure = true, onSubmit = ::submit)
    }
    error?.let { ErrorLine(it) }
    PrimaryButton("Iniciar sesión", Modifier.fillMaxWidth(), enabled = canSubmit, loading = busy, onClick = ::submit)
}

@Composable
private fun RegisterForm() {
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    var name by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var confirm by rememberSaveable { mutableStateOf("") }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    var busy by rememberSaveable { mutableStateOf(false) }

    val lengthOk = password.length in 10..25
    val upperOk = password.any { it.isUpperCase() }
    val valid = email.isNotBlank() && lengthOk && upperOk && password == confirm

    fun submit() {
        if (!valid) {
            error = when {
                !lengthOk -> "La contraseña debe tener entre 10 y 25 caracteres."
                !upperOk -> "La contraseña debe contener al menos una letra mayúscula."
                password != confirm -> "Las contraseñas no coinciden."
                else -> null
            }
            return
        }
        busy = true
        error = null
        scope.launch {
            try {
                app.register(email.trim(), password, name.trim().ifEmpty { null })
            } catch (e: Exception) {
                error = e.message ?: "Error al registrar usuario."
            }
            busy = false
        }
    }

    LabeledField("Nombre completo (opcional)") { DField(name, { name = it }, "Diego Cainzos", imeAction = ImeAction.Next) }
    LabeledField("Correo electrónico") {
        DField(email, { email = it }, "usuario@ejemplo.com", keyboardType = KeyboardType.Email, imeAction = ImeAction.Next)
    }
    LabeledField("Contraseña") {
        DField(password, { password = it }, "Entre 10 y 25 caracteres", secure = true, imeAction = ImeAction.Next)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(top = 2.dp)) {
            Requirement(lengthOk, "Entre 10 y 25 caracteres (${password.length}/25)")
            Requirement(upperOk, "Al menos una letra mayúscula")
        }
    }
    LabeledField("Confirmar contraseña") {
        DField(confirm, { confirm = it }, "Repite tu contraseña", secure = true, onSubmit = ::submit)
        if (confirm.isNotEmpty()) {
            val match = password == confirm
            Requirement(match, if (match) "Las contraseñas coinciden" else "Las contraseñas no coinciden", badIcon = Icons.Outlined.Cancel)
        }
    }
    error?.let { ErrorLine(it) }
    PrimaryButton("Crear cuenta", Modifier.fillMaxWidth(), enabled = valid && !busy, loading = busy, onClick = ::submit)
}
