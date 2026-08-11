# Tareas — Rediseño Integral Apple Music Web

## 1. Tokens de Sistema de Diseño (`DiegoTheme`)

- [ ] 1.1 Actualizar `DiegoTheme.accent` a `#FA233C`, añadir constantes para materiales glassmorphism, sombras y superficies en `DiegoMusic/Design/DesignSystem.swift`.

## 2. Historial de Navegación (`NavigationHistoryStore`)

- [ ] 2.1 Crear `NavigationHistoryStore` en `DiegoMusic/App/RootView.swift` o módulo dedicado con pilas `backStack` y `forwardStack`.
- [ ] 2.2 Integrar la cabecera superior con botones Atrás `<` y Adelante `>` en `RootView.swift`.

## 3. Dock de Reproducción Apple Music Web (`PlayerDock`)

- [ ] 3.1 Rediseñar `PlayerDock.swift` con layout de tres columnas (metadatos + corazón, controles + scrubber de tiempo interactivo, volumen + botones de letras y cola).
- [ ] 3.2 Conectar el control de volumen con `player.volume`.

## 4. Alineación Visual de Vistas (`HomeView`, `SearchView`, `LibraryView`)

- [ ] 4.1 Actualizar hero banners, tarjetas de contenidos y listados para imitar la estética de `browse.png`, `radio.png`, `library.png` y `album_detail.png`.

## 5. Validación

- [ ] 5.1 Ejecutar validación OpenSpec con `.pi/openspec/node_modules/.bin/openspec validate apple-music-ui-redesign --type change --strict`.
- [ ] 5.2 Compilar y verificar suite de pruebas con `./scripts/validate.sh`.
