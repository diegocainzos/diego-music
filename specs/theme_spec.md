# Especificación de Tema y Sistema de Diseño (Theme Spec)

## 1. Visión General
Definición del sistema de diseño unificado e inspirante de Apple Music con soporte completo para Modo Claro (Light Mode) y Modo Oscuro (Dark Mode), adaptable dinámicamente mediante `@Environment(\.colorScheme)`.

## 2. Paleta de Colores y Tokens

### 2.1 Acento Principal
- **Apple Red**: `#FA2D48` (RGB: 250, 45, 72)
- **Hover/Pressed**: `#D6203B`

### 2.2 Modo Oscuro (Dark Mode)
- **Fondo Base (Background)**: `#000000` (Negro Puro OLED) / `#1C1C1E` (Gris Oscuro de tarjeta)
- **Superficie de Tarjetas (Surface)**: `#1C1C1E` con borde sutil `rgba(255, 255, 255, 0.08)`
- **Efecto Glassmorphic**: Material translúcido `.ultraThinMaterial` / `.thinMaterial` sobre fondo oscuro con opacidad de 85% y desenfoque (blur 20pt)
- **Texto Primario**: `#FFFFFF`
- **Texto Secundario**: `rgba(255, 255, 255, 0.60)`
- **Texto Terciario/Muted**: `rgba(255, 255, 255, 0.35)`

### 2.3 Modo Claro (Light Mode)
- **Fondo Base (Background)**: `#FFFFFF` (Blanco Puro) / `#F2F2F7` (Gris Claro de superficie)
- **Superficie de Tarjetas (Surface)**: `#F2F2F7` con borde sutil `rgba(0, 0, 0, 0.06)`
- **Efecto Glassmorphic**: Material translúcido `.regularMaterial` / `.ultraThinMaterial` sobre fondo claro con opacidad de 88%
- **Texto Primario**: `#000000`
- **Texto Secundario**: `rgba(0, 0, 0, 0.60)`
- **Texto Terciario/Muted**: `rgba(0, 0, 0, 0.35)`

## 3. Tipografía
- **Familia**: SF Pro / Inter
- **Encabezados Principales**: `.font(.system(size: 28, weight: .bold))`
- **Eyebrows (Secciones)**: `.font(.caption.bold())` con `tracking(1.2)` en color de acento `#FA2D48`
- **Títulos de Canción/Álbum**: `.font(.system(.body, design: .default, weight: .semibold))`
- **Subtítulos de Artista/Canal**: `.font(.subheadline)`

## 4. Reglas de Cambio Dinámico de Tema
- La app debe respetar `@Environment(\.colorScheme)` o la preferencia seleccionada en Ajustes (`PlaybackSettings.themeMode`).
- `DiegoTheme` expondrá propiedades adaptativas dinámicas basadas en `ColorScheme`:
  - `DiegoTheme.background(for: scheme)`
  - `DiegoTheme.surface(for: scheme)`
  - `DiegoTheme.textPrimary(for: scheme)`
  - `DiegoTheme.textSecondary(for: scheme)`
  - `DiegoTheme.accent` -> `#FA2D48`

## 5. Criterios de Aceptación
- [ ] Cambio suave al conmutar entre Modo Claro y Modo Oscuro en tiempo de ejecución.
- [ ] Mantenimiento del contraste WCAG AA en ambos modos.
- [ ] Tarjetas y reproductor Dock con bordes y fondos translúcidos fluidos.
