## Why

Construir una primera versión funcional de DiegoMusic convierte la especificación educativa existente en una aplicación Apple multiplataforma verificable, centrada en aprendizaje de SwiftUI, APIs oficiales de YouTube, reproducción web y privacidad local. El proyecto parte sin código y necesita una base coherente que funcione en iPhone, iPad y macOS sin publicar credenciales ni presentarse como producto oficial.

## What Changes

- Crear una aplicación SwiftUI llamada DiegoMusic para iOS/iPadOS 17 y macOS 13, con bundle `com.diegocainzos.DiegoMusic`.
- Implementar navegación adaptable, estética propia Bauhaus digital + Hi‑Fi skeuomórfica, reproductor compacto y animaciones expresivas respetando accesibilidad.
- Integrar YouTube Data API v3 para búsqueda y metadatos con estados de carga, vacío, error y cuota.
- Integrar YouTube IFrame Player API dentro de `WKWebView`, con puente Swift–JavaScript y cola local.
- Persistir favoritos, playlists, historial y preferencias con Core Data, ya que macOS 13 no admite SwiftData.
- Añadir PrivacyShield mediante listas de contenido WebKit, reglas incluidas, importación local, modo agresivo opcional y entorno controlado de pruebas.
- Leer `YOUTUBE_DATA_KEY` desde configuración local excluida sin registrar ni versionar su valor.
- Añadir pruebas unitarias, integración del puente web y validaciones de seguridad.

## Capabilities

### New Capabilities

- `adaptive-app-shell`: navegación y presentación adaptables para iPhone, iPad y macOS con identidad DiegoMusic.
- `youtube-catalog`: búsqueda y transformación de contenido público mediante YouTube Data API v3.
- `official-web-player`: reproducción con YouTube IFrame Player API, puente Swift–JavaScript y cola local.
- `local-music-library`: favoritos, playlists, historial y ajustes persistidos localmente con Core Data.
- `privacy-shield`: compilación, instalación, configuración y prueba de reglas locales de contenido.
- `secure-local-configuration`: inyección local y no versionada de la clave de YouTube.
- `bauhaus-hifi-design-system`: componentes visuales, controles expresivos, color, movimiento y accesibilidad propios.

### Modified Capabilities

Ninguna; el repositorio no contiene capacidades OpenSpec previas.

## Impact

Se incorporarán un proyecto Xcode y código Swift/SwiftUI, recursos HTML/JavaScript/JSON, configuración de compilación local, un almacén Core Data y suites de pruebas. La aplicación dependerá de YouTube Data API v3, YouTube IFrame Player API y WebKit, manteniendo la reproducción oficial y sin extraer URLs multimedia. El bloqueo sobre contenido real será de mejor esfuerzo por las restricciones de origen y la evolución de la infraestructura de YouTube; el comportamiento determinista se demostrará en un entorno controlado.
