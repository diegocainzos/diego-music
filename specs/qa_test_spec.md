# Especificación de Pruebas y QA Visual (QA Test Spec)

## 1. Visión General
Plan de verificación end-to-end (E2E), QA de regresión visual y lista de capturas obligatorias para validar que la aplicación cumple con el diseño de Apple Music Web en ambos modos (Modo Claro y Modo Oscuro).

## 2. Lista de Capturas de Pantalla Obligatorias (`/tmp/qa_screenshots/`)

### 2.1 Modo Oscuro (Dark Mode)
1. `dark_home.png`: Inicio / Escuchar con Hero Banners y Top Artistas circulares.
2. `dark_search.png`: Búsqueda con chips horizontales y menú contextual de 3 puntos.
3. `dark_library.png`: Biblioteca con tabla de canciones y rejilla de álbumes.
4. `dark_player.png`: Mini-player flotante e interfaz expandida Now Playing.
5. `dark_artist.png`: Perfil de Artista con cabecera y top tracks.

### 2.2 Modo Claro (Light Mode)
1. `light_home.png`: Inicio / Escuchar en Modo Claro.
2. `light_search.png`: Búsqueda en Modo Claro.
3. `light_library.png`: Biblioteca en Modo Claro.
4. `light_player.png`: Reproductor en Modo Claro.
5. `light_artist.png`: Perfil de Artista en Modo Claro.

## 3. Matriz de Pruebas de Comportamiento e Interacción

| ID | Área | Descripción | Resultado Esperado |
|---|---|---|---|
| TC-01 | Temas | Cambio dinámico entre Modo Claro y Oscuro | La UI ajusta backgrounds, tarjetas y textos sin reiniciar el reproductor. |
| TC-02 | Layout | Posicionamiento del PlayerDock y TabBar | El PlayerDock no tapa los botones del TabBar y el contenido de las listas llega al final. |
| TC-03 | Navegación | Pulsación en pestaña activa | Se resetea el stack de navegación a la raíz de la pestaña. |
| TC-04 | Home | Avatares circulares de Top Artistas | Al pulsar en la foto de un artista abre `ArtistView`. |
| TC-05 | Reproductor | Control de barra de progreso y volumen | El scrubber se arrastra suavemente y actualiza el tiempo del `AVPlayer`. |

## 4. Criterios de Aprobación Final
- [ ] `./scripts/validate.sh` pasa al 100% (`TEST SUCCEEDED`, `TEST BUILD SUCCEEDED`).
- [ ] Todas las capturas en `/tmp/qa_screenshots/` muestran una UI impecable en Modo Claro y Oscuro.
- [ ] Sin solapamientos visuales ni bloqueos de toque en los botones del TabBar.
