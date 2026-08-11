# 05 — QA Iterativo y Plan de Verificación (QA Spec)

## 1. Visión General
Criterios de aceptación detallados y plan de pruebas obligatorios para verificar el 100% de la funcionalidad y fidelidad visual respecto a Apple Music Web.

## 2. Checklist de Criterios de Aceptación

- [ ] **Check 1: Logo e Identidad**
  - El logotipo de Apple Music figura en la barra lateral, cabecera y metadatos de la app.
- [ ] **Check 2: Selector de Tema**
  - El toggle de tema (Oscuro, Claro, Sistema) en Ajustes y cabecera funciona y persiste tras reiniciar.
- [ ] **Check 3: Calidad de Temas**
  - Los temas Claro y Oscuro aplican perfectamente en todas las pantallas sin fallos de contraste.
- [ ] **Check 4: Variedad en Home**
  - La pantalla Inicio ("Escuchar") incluye al menos 6-8 artistas destacados de diversos géneros en lugar de repeticiones.
- [ ] **Check 5: Vista de Artista**
  - La pantalla de artista incluye foto de portada gigante, insignia de verificado, top canciones numeradas y discografía.
- [ ] **Check 6: Crear Playlist**
  - El botón "Crear Playlist" abre modal interactivo, crea la playlist y la muestra en Sidebar/Biblioteca de inmediato.
- [ ] **Check 7: Layout Player vs Docker**
  - El reproductor mini no solapa el Docker/TabBar inferior ni bloquea botones táctiles.
- [ ] **Check 8: Navegación e Historial**
  - Las flechas atrás/adelante (`<` y `>`) funcionan y pulsar en la pestaña activa resetea la ruta a la raíz.

## 3. Plan de Capturas de Pantalla (/tmp/qa_overhaul/)
- `dark_home.png` & `light_home.png`
- `dark_artist.png` & `light_artist.png`
- `dark_playlist_modal.png` & `light_playlist_modal.png`
- `dark_player_dock.png` & `light_player_dock.png`

## 4. Criterio de Finalización
No se declarará terminado el trabajo hasta que el 100% de los 8 puntos del checklist estén verificados con capturas y pruebas unitarias/build pasadas (`./scripts/validate.sh`).
