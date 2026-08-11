# Cambio: Rediseño integral Apple Music Web Overhaul

## Why

Para clonar al 100% la experiencia oficial de Apple Music Web, es necesario renovar la identidad visual y logo, proporcionar variedad multicultural en la pantalla inicial "Escuchar", implementar la vista de perfil de artista completa, arreglar el flujo interactivo de creación de playlists, garantizar cero solapamiento entre el reproductor y la barra de pestañas, y verificar exhaustivamente en Modo Claro y Oscuro.

## What Changes

- **Identidad & Logo**: Logotipo Apple Music con nota musical `♫` roja, metadatos y selector de tema persistente (Oscuro, Claro, Sistema).
- **Home "Escuchar"**: Variedad de catálogo (6-8+ artistas diversos), carrusel Hero y avatares circulares `Circle()`.
- **Vista de Artista**: Foto gigante, badge de verificado, top canciones numeradas y discografía.
- **Playlists & Layout**: Modal interactivo para crear playlists, reseteo de rutas al pulsar pestañas y player dock posicionado sin solapar la barra inferior.

## Capabilities

### Modified Capabilities

- `apple-music-aesthetic`: fidelidad total a Apple Music Web en identidad, catálogo, reproductor y navegación.

## Impact

- Cliente Swift: `DiegoMusic/App/*`, `DiegoMusic/Design/*`, `DiegoMusic/Features/*`.
