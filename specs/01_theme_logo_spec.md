# 01 — Identidad Visual, Logo y Sistema de Temas (Theme & Logo Spec)

## 1. Identidad Visual y Logotipo Apple Music

### 1.1 Icono de la App e Identidad
- **Icono de la App**: Degradado de rojo-rosa Apple Music (`#FC3C44` a `#FF2D55`) con nota musical octava `♫` blanca brillante centrada.
- **Logotipo en Cabecera (Sidebar / Header)**: Icono de nota musical roja + texto "Music" en tipografía bold SF Pro / Inter.
- **Metadatos y Favicon**: Título de la app "Apple Music" / "DiegoMusic — Apple Music" y favicon con la nota musical `♫`.

### 1.2 Sistema de Temas Dinámico

#### Modo Oscuro (Dark Mode)
- **Fondo Principal**: `#000000` (OLED Black)
- **Fondo Secundario / Tarjetas**: `#1C1C1E` con bordes sutiles `rgba(255, 255, 255, 0.08)`
- **Acento Principal**: Rojo Apple Music `#FA2D48` (RGB: 250, 45, 72)
- **Efectos Glassmorphic**: Material translúcido `.ultraThinMaterial` / `.thinMaterial`
- **Textos**: Primario `#FFFFFF`, Secundario `#8E8E93`

#### Modo Claro (Light Mode)
- **Fondo Principal**: `#FFFFFF` (Blanco Puro)
- **Fondo Secundario / Tarjetas**: `#F2F2F7` con sombras suaves y borde `rgba(0, 0, 0, 0.06)`
- **Acento Principal**: Rojo Apple Music `#FA2D48`
- **Textos**: Primario `#1C1C1E`, Secundario `#8E8E93`

### 1.3 Selector y Lógica de Persistencia
- Toggle funcional en Ajustes y cabecera con opciones: **Oscuro**, **Claro**, **Sistema**.
- Persistencia en `PlaybackSettings` (`playback.themeMode`).
- Aplicación síncrona mediante `.preferredColorScheme(themeMode.colorScheme)` en `RootView`.

## 2. Criterios de Aceptación
- [ ] El logotipo de Apple Music figura en la cabecera, sidebar y metadatos de la app.
- [ ] El toggle de tema conmuta dinámicamente entre Claro, Oscuro y Sistema sin errores visuales.
- [ ] Mantenimiento del contraste WCAG AA en todas las pantallas.
