# 04 — Playlists, Reproductor y Navegación (Playlist, Player & Navigation Spec)

## 1. Visión General
Especificación técnica para la creación interactiva de playlists, el ajuste perfecto del reproductor mini respecto a la barra de pestañas (Docker/TabBar), la pila de navegación con historial (`<` y `>`), y la experiencia Now Playing expandida.

## 2. Creación e Interacción con Playlists

### 2.1 Botón "Crear Playlist" y Modal Interactivo
- El botón "+ Crear Playlist" abre un modal interactivo (`CreatePlaylistSheet`).
- El modal incluye:
  - Campo de texto para el Nombre de la Playlist.
  - Descripción opcional.
  - Selector de estilo/icono o portada predeterminada.
  - Botones "Cancelar" y "Crear".
- Al pulsar "Crear", la playlist se guarda en el estado global (`LibraryStore`), se muestra inmediatamente en la sección Playlists del Sidebar y de la Biblioteca, y navega automáticamente a la vista de la nueva playlist.

## 3. Evitación de Solapamientos (Player vs Docker/TabBar)

### 3.1 Layout de Capas e Insets
- El reproductor flotante (`PlayerDock`) se posiciona por encima del `TabBar` utilizando `.safeAreaInset(edge: .bottom)` o `VStack(spacing: 0)` con z-index estricto:
  - ZIndex 0: ScrollView de contenido principal (con padding inferior suficiente).
  - ZIndex 1: Reproductor Mini (`PlayerDock`).
  - ZIndex 2: Barra de Pestañas inferior (`PhoneTabBar`).
- Ningún botón del `TabBar` queda tapado ni bloqueado por el reproductor.

## 4. Pila de Navegación e Historial

### 4.1 Flechas Atrás `<` y Adelante `>`
- Botones de navegación en la cabecera del escritorio vinculados a `NavigationState` (`canGoBack`, `canGoForward`, `goBack()`, `goForward()`).

### 4.2 Reseteo de Rutas al pulsar sobre Pestaña Activa
- Tocar sobre el icono de una pestaña seleccionada (ej. Búsqueda o Inicio) resetea la pila a la pantalla raíz de esa pestaña, permitiendo salir libremente de sub-rutas o resultados.

## 5. Experiencia Now Playing Expandida
- Fondo con degradado animado extraído de la portada en reproducción (*Dynamic Canvas*).
- Sheet a pantalla completa con letras sincronizadas y gestión de cola.

## 6. Criterios de Aceptación
- [ ] El botón "Crear Playlist" abre modal, guarda y muestra la playlist de inmediato.
- [ ] El mini-player no tapona los botones del TabBar.
- [ ] Flechas `<` y `>` operativas y reseteo de pestañas activo.
