## 1. Configuración reproducible

- [x] 1.1 Crear `.gitignore`, configuración local de secretos y script seguro para generar `Secrets.xcconfig` desde `.env`
- [x] 1.2 Definir `project.yml` multiplataforma y script local de generación del proyecto Xcode
- [x] 1.3 Crear estructura de fuentes, recursos y pruebas de DiegoMusic

## 2. Dominio, red y configuración

- [x] 2.1 Implementar modelos de dominio, cola reproducible y estados de carga
- [x] 2.2 Implementar configuración API sin filtraciones y transporte URLSession inyectable
- [x] 2.3 Implementar endpoint, DTOs, mapper y servicio de búsqueda YouTube
- [x] 2.4 Añadir pruebas de endpoint, decodificación, mapeo, cuota y cola

## 3. Reproductor oficial

- [x] 3.1 Crear `player.html` con IFrame Player API, comandos y eventos tipados
- [x] 3.2 Implementar coordinador del reproductor y decodificación segura de mensajes
- [x] 3.3 Implementar adaptadores WKWebView para iOS y macOS conservando estado
- [x] 3.4 Añadir pruebas del protocolo de mensajes y recursos web

## 4. PrivacyShield

- [x] 4.1 Implementar modelos, modos, carga y compilación de reglas WebKit
- [x] 4.2 Añadir listas equilibrada, agresiva y controlada con allowlist multimedia
- [x] 4.3 Crear página controlada y diagnóstico local reversible
- [x] 4.4 Añadir pruebas de reglas, configuración y recuperación

## 5. Biblioteca local

- [x] 5.1 Implementar modelos Core Data para favoritos, playlists e historial
- [x] 5.2 Implementar operaciones de biblioteca sin duplicación y vistas de favoritos/playlists
- [x] 5.3 Persistir preferencias de PrivacyShield y reproducción local

## 6. Interfaz Bauhaus Hi‑Fi

- [x] 6.1 Crear tokens y componentes accesibles del sistema visual Bauhaus Hi‑Fi
- [x] 6.2 Implementar shell adaptable, Inicio, Búsqueda, Biblioteca, Playlists y Ajustes
- [x] 6.3 Implementar mini reproductor discreto, vista ampliada y controles expresivos
- [x] 6.4 Añadir animaciones abundantes compatibles con Reducir movimiento

## 7. Validación y documentación

- [x] 7.1 Generar el proyecto y ejecutar validaciones estáticas disponibles sin Xcode
- [ ] 7.2 Compilar y probar iOS 17 y macOS 13 cuando Xcode esté disponible
- [x] 7.3 Verificar que secretos y logs no exponen `YOUTUBE_DATA_KEY`
- [x] 7.4 Documentar configuración, ejecución, límites de bloqueo y pruebas
- [x] 7.5 Validar el cambio completo con OpenSpec
