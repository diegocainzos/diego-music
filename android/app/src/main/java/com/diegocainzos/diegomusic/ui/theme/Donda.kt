package com.diegocainzos.diegomusic.ui.theme

import android.graphics.Typeface
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.diegocainzos.diegomusic.data.AppThemeMode

// MARK: - Tokens Donda (iguales que DesignSystem.swift)

@Immutable
data class DondaColors(
    val background: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val hairline: Color,
    val outline: Color,
) {
    /** En Donda no hay acento: coincide con `textPrimary`. */
    val accent: Color get() = textPrimary
}

val DondaBlack = DondaColors(Color(0xFF000000), Color(0xFFE9E9E9), Color(0xFF666666), Color(0xFF1B1B1B), Color(0xFF333333))
val DondaWhite = DondaColors(Color(0xFFFFFFFF), Color(0xFF111111), Color(0xFF8A8A8A), Color(0xFFECECEC), Color(0xFFCFCFCF))

val LocalDonda = staticCompositionLocalOf { DondaBlack }

object Donda {
    val colors: DondaColors @Composable get() = LocalDonda.current
    val mono = FontFamily.Monospace
    /** Fuente condensada del sistema (`sans-serif-condensed`); no se empaquetan fuentes. */
    val condensed = FontFamily(Typeface.create("sans-serif-condensed", Typeface.NORMAL))
}

private fun scheme(c: DondaColors, dark: Boolean): ColorScheme {
    val base = if (dark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = c.textPrimary, onPrimary = c.background, secondary = c.textSecondary,
        background = c.background, onBackground = c.textPrimary, surface = c.background, onSurface = c.textPrimary,
        surfaceVariant = c.background, onSurfaceVariant = c.textSecondary, surfaceContainer = c.background,
        surfaceContainerHigh = c.background, surfaceContainerLow = c.background, surfaceContainerHighest = c.background,
        surfaceContainerLowest = c.background, outline = c.outline, outlineVariant = c.hairline, surfaceTint = Color.Transparent,
    )
}

@Composable
fun DondaTheme(mode: AppThemeMode, content: @Composable () -> Unit) {
    val colors = if (mode == AppThemeMode.WHITE) DondaWhite else DondaBlack
    val square = remember { Shapes(Square, Square, Square, Square, Square) }
    MaterialTheme(colorScheme = scheme(colors, mode == AppThemeMode.BLACK), shapes = square) {
        CompositionLocalProvider(LocalDonda provides colors, LocalContentColor provides colors.textPrimary, content = content)
    }
}

// MARK: - Tipografía (`dondaLabel` / `dondaTitle`)

/** Monoespaciada, mayúsculas, tracking 1,4 (o el indicado). */
@Composable
fun DLabel(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = Donda.colors.textSecondary,
    size: TextUnit = 11.sp,
    tracking: TextUnit = 1.4.sp,
    maxLines: Int = Int.MAX_VALUE,
    weight: FontWeight = FontWeight.Normal,
    align: TextAlign? = null,
) = Text(
    text.uppercase(),
    modifier = modifier,
    color = color,
    style = TextStyle(fontFamily = Donda.mono, fontSize = size, letterSpacing = tracking, fontWeight = weight),
    maxLines = maxLines,
    overflow = TextOverflow.Ellipsis,
    textAlign = align,
)

/** Condensada, peso regular, mayúsculas, tracking 2,4 (o el indicado). */
@Composable
fun DTitle(
    text: String,
    size: TextUnit = 20.sp,
    modifier: Modifier = Modifier,
    color: Color = Donda.colors.textPrimary,
    tracking: TextUnit = 2.4.sp,
    maxLines: Int = Int.MAX_VALUE,
    align: TextAlign? = null,
) = Text(
    text.uppercase(),
    modifier = modifier,
    color = color,
    style = TextStyle(fontFamily = Donda.condensed, fontSize = size, letterSpacing = tracking),
    maxLines = maxLines,
    overflow = TextOverflow.Ellipsis,
    textAlign = align,
)

/** Texto de cuerpo (`.system(size:)` en Swift). */
@Composable
fun DText(
    text: String,
    modifier: Modifier = Modifier,
    size: TextUnit = 14.sp,
    color: Color = Donda.colors.textPrimary,
    maxLines: Int = Int.MAX_VALUE,
    weight: FontWeight = FontWeight.Normal,
    align: TextAlign? = null,
    mono: Boolean = false,
    lineHeight: TextUnit = TextUnit.Unspecified,
) = Text(
    text,
    modifier = modifier,
    color = color,
    fontSize = size,
    fontWeight = weight,
    fontFamily = if (mono) Donda.mono else null,
    maxLines = maxLines,
    overflow = TextOverflow.Ellipsis,
    textAlign = align,
    lineHeight = lineHeight,
)

// MARK: - Componentes base

fun Modifier.hairlineBorder(color: Color) = border(1.dp, color, RectangleShape)

fun Modifier.plainClickable(enabled: Boolean = true, onClick: () -> Unit) =
    clickable(interactionSource = MutableInteractionSource(), indication = null, enabled = enabled, onClick = onClick)

/** Carátula cuadrada, radio 0, borde hairline; sin imagen queda un cuadrado del color de fondo. */
@Composable
fun TrackArtwork(url: String?, modifier: Modifier = Modifier) {
    val c = Donda.colors
    Box(modifier.background(c.background).hairlineBorder(c.hairline)) {
        if (url != null) {
            AsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.matchParentSize().padding(1.dp),
            )
        }
    }
}

@Composable
fun Hairline(modifier: Modifier = Modifier) = Box(modifier.fillMaxWidth().height(1.dp).background(Donda.colors.hairline))

/** Chip/segmento: invertido cuando está activo, borde `outline`. */
@Composable
fun DChip(text: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = Donda.colors
    Box(
        modifier
            .background(if (selected) c.textPrimary else c.background)
            .hairlineBorder(c.outline)
            .plainClickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        DLabel(text, color = if (selected) c.background else c.textPrimary, maxLines = 1)
    }
}

/** `PrimaryButtonStyle`: relleno `textPrimary`, etiqueta `background`, alto mínimo 44. */
@Composable
fun PrimaryButton(
    text: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    loading: Boolean = false,
    onClick: () -> Unit,
) {
    val c = Donda.colors
    Row(
        modifier
            .heightIn(min = 44.dp)
            .background(if (enabled) c.textPrimary else c.textPrimary.copy(alpha = 0.4f))
            .hairlineBorder(c.outline)
            .plainClickable(enabled = enabled && !loading, onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (loading) {
            androidx.compose.material3.CircularProgressIndicator(Modifier.size(14.dp), color = c.background, strokeWidth = 1.5.dp)
            Spacer(Modifier.size(8.dp))
        } else if (icon != null) {
            Icon(icon, null, tint = c.background, modifier = Modifier.size(14.dp))
            Spacer(Modifier.size(6.dp))
        }
        DLabel(text, color = c.background, maxLines = 1)
    }
}

/** Botón contorneado con fondo `background` (acciones secundarias). */
@Composable
fun OutlineButton(
    text: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    selected: Boolean = false,
    enabled: Boolean = true,
    horizontal: Dp = 14.dp,
    vertical: Dp = 8.dp,
    onClick: () -> Unit,
) {
    val c = Donda.colors
    val fg = if (selected) c.background else c.textPrimary
    Row(
        modifier
            .background(if (selected) c.textPrimary else c.background)
            .hairlineBorder(c.outline)
            .plainClickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = horizontal, vertical = vertical),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = fg, modifier = Modifier.size(12.dp))
            Spacer(Modifier.size(6.dp))
        }
        DLabel(text, color = fg, maxLines = 1)
    }
}

/** Icono pulsable con área táctil cuadrada. */
@Composable
fun IconTap(
    icon: ImageVector,
    description: String,
    modifier: Modifier = Modifier,
    size: Dp = 36.dp,
    iconSize: Dp = 16.dp,
    tint: Color = Donda.colors.textPrimary,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Box(modifier.size(size).plainClickable(enabled = enabled, onClick = onClick), contentAlignment = Alignment.Center) {
        Icon(icon, description, tint = tint, modifier = Modifier.size(iconSize))
    }
}

/** `EmptyStateView`. */
@Composable
fun EmptyState(
    title: String,
    icon: ImageVector,
    description: String,
    modifier: Modifier = Modifier,
    actionTitle: String? = null,
    action: (() -> Unit)? = null,
) {
    val c = Donda.colors
    Column(
        modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(icon, null, tint = c.textSecondary, modifier = Modifier.size(42.dp))
        DTitle(title, 18.sp, align = TextAlign.Center)
        DText(description, size = 15.sp, color = c.textSecondary, align = TextAlign.Center, modifier = Modifier.widthIn(max = 460.dp))
        if (actionTitle != null && action != null) PrimaryButton(actionTitle, onClick = action)
    }
}

/** Toast invertido (pantallas) o contorneado (reproductor). */
@Composable
fun DToast(text: String, inverted: Boolean = true, modifier: Modifier = Modifier) {
    val c = Donda.colors
    Box(
        modifier
            .background(if (inverted) c.textPrimary else c.background)
            .hairlineBorder(c.outline)
            .padding(horizontal = 16.dp, vertical = 10.dp),
    ) {
        DLabel(text, color = if (inverted) c.background else c.textPrimary)
    }
}

/** Cabecera de sección: etiqueta con tracking 4. */
@Composable
fun SectionHeader(title: String, modifier: Modifier = Modifier) =
    DLabel(title, modifier = modifier.fillMaxWidth(), tracking = 4.sp)

/** `minimalCard()`: padding 16, borde `outline`. */
fun Modifier.minimalCard(c: DondaColors) = background(c.background).hairlineBorder(c.outline).padding(16.dp)

/** Barra de progreso de 1 dp. */
@Composable
fun ProgressLine(fraction: Float, modifier: Modifier = Modifier) {
    val c = Donda.colors
    Box(modifier.fillMaxWidth().height(1.dp).background(c.hairline)) {
        Box(Modifier.fillMaxWidth(fraction.coerceIn(0f, 1f)).height(1.dp).background(c.textPrimary))
    }
}

/** Forma sin radio para los componentes Material que lo pidan. */
val Square = RoundedCornerShape(0.dp)
