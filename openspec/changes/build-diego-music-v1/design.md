## Context

DiegoMusic parte de una especificación y un archivo local `.env`, sin proyecto Xcode ni código previo. Debe ejecutarse como aplicación privada y educativa en iOS/iPadOS 17 y macOS 13, compartir la mayor parte del código, usar APIs oficiales de YouTube y proteger configuración y datos locales. La interfaz combinará geometría Bauhaus con controles Hi‑Fi skeuomórficos, manteniendo un tono experimental, tranquilo y lúdico.

El entorno aún no dispone de Xcode seleccionado durante la implementación; por eso el proyecto se declarará de forma reproducible y se aplicarán validaciones estáticas hasta que Xcode permita ejecutar compilaciones y simuladores.

## Goals / Non-Goals

**Goals:**

- Entregar una base multiplataforma compilable, modular y probada.
- Buscar contenido musical público y reproducir vídeos con el IFrame Player oficial.
- Mantener cola, favoritos, playlists e historial local con Core Data.
- Aplicar reglas WebKit transparentes, configurables y recuperables.
- Evitar que `YOUTUBE_DATA_KEY` aparezca en fuentes, historial o logs.
- Ofrecer una interfaz informativa con reproductor discreto, controles expresivos y animación abundante accesible.

**Non-Goals:**

- Publicar la aplicación, suplantar a YouTube o usar marcas oficiales.
- Iniciar sesión con Google, sincronizar por iCloud o reproducir audio en segundo plano en v1.
- Extraer URLs de audio/vídeo o sustituir el reproductor oficial.
- Prometer bloqueo universal de publicidad dentro de un iframe de otro origen.

## Decisions

### Proyecto reproducible con XcodeGen

Se mantendrá `project.yml` como fuente del proyecto y se generará `DiegoMusic.xcodeproj`. Un único target de aplicación admitirá iOS y macOS, acompañado de un target de pruebas. Esto evita editar manualmente `project.pbxproj` y permite regenerarlo cuando Xcode esté disponible. Alternativa descartada: mantener un `.xcodeproj` escrito manualmente, por fragilidad y ruido.

### Arquitectura por capacidades e inyección sencilla

`AppEnvironment` construirá servicios mediante protocolos: cliente de YouTube, biblioteca y motor PrivacyShield. Los estados de UI se aislarán en modelos `@MainActor`. Los DTOs permanecerán separados de los modelos de dominio. Alternativa descartada: un contenedor de dependencias externo; no aporta valor al alcance educativo.

### Core Data para persistencia compatible

SwiftData requiere macOS 14, por lo que no es compatible con el mínimo macOS 13 acordado. Favoritos, playlists, elementos, historial y preferencias se persistirán con un modelo Core Data creado de forma reproducible en código. La cola seguirá en memoria. Alternativa descartada: mantener dos almacenes condicionales SwiftData/Core Data, porque duplicaría la lógica y las migraciones sin aportar valor a v1.

### Cliente YouTube basado en URLSession

El servicio construirá `search.list` con `part=snippet`, `type=video`, `videoCategoryId=10`, `videoEmbeddable=true` y `safeSearch=moderate`. Un protocolo de transporte permitirá fixtures deterministas. Los errores HTTP, ausencia de clave y cuota se mapearán a estados de dominio.

### Clave local mediante xcconfig generado

Un script leerá `YOUTUBE_DATA_KEY` desde `.env` sin imprimirlo y generará `Config/Secrets.xcconfig`, excluido del control de versiones. El build setting se incorporará al Info.plist generado y se leerá en ejecución. La clave queda necesariamente embebida en una aplicación cliente, por lo que debe restringirse en Google Cloud.

### Reproductor oficial aislado

`player.html` cargará IFrame Player API y expondrá comandos pequeños (`load`, `play`, `pause`, `seek`). Los eventos se enviarán a Swift mediante un único handler. `WKWebView` tendrá adaptadores `UIViewRepresentable` y `NSViewRepresentable`; el coordinador conservará estado al cambiar entre mini reproductor y vista completa.

### PrivacyShield por capas

`WKContentRuleListStore` compilará listas incluidas y personalizadas antes de crear la navegación. Habrá modo equilibrado y agresivo, interruptor global, caché y recuperación sin reglas si falla la reproducción. El modo equilibrado bloqueará hosts publicitarios conocidos y recursos controlados; el agresivo añadirá patrones de anuncios de YouTube con riesgo explícito. La validación determinista se realizará contra `controlled-test.html`; el contenido real será mejor esfuerzo por aislamiento de origen e infraestructura compartida.

### Sistema visual Bauhaus Hi‑Fi

El diseño utilizará rojo, amarillo y azul primarios cálidos sobre superficies crema/carbón; formas geométricas, contornos visibles, sombras físicas y controles inspirados en equipos Hi‑Fi. La información conservará densidad equilibrada. Las transiciones usarán resortes y rotación, pero respetarán `accessibilityReduceMotion`, contraste y áreas táctiles.

## Risks / Trade-offs

- [Xcode aún no disponible] → Mantener generación reproducible, validar sintaxis y ejecutar toda la matriz cuando Xcode termine de instalarse.
- [La clave acaba embebida en el binario] → Excluirla de fuentes/logs y restringirla por API/cuota en Google Cloud.
- [Las reglas agresivas pueden bloquear reproducción] → Modo opcional, allowlist de medios, diagnóstico local y recuperación al modo equilibrado/desactivado.
- [YouTube cambia endpoints o estados] → Reglas importables, pruebas del bridge independientes y manejo explícito de errores.
- [Core Data y WebKit dificultan tests puros] → Usar un almacén Core Data en memoria y separar modelos/compiladores mediante protocolos.
- [Animación abundante puede distraer] → Reducir o eliminar movimiento cuando el sistema lo solicite.

## Migration Plan

1. Generar configuración local desde `.env` y el proyecto desde `project.yml`.
2. Compilar primero sin filtros y con respuestas de prueba.
3. Validar búsqueda real con una clave restringida.
4. Validar el IFrame oficial y después instalar reglas equilibradas.
5. Activar el modo agresivo únicamente como preferencia explícita y reversible.
6. Ante regresión, regenerar el proyecto y desactivar PrivacyShield sin perder la biblioteca local.

## Open Questions

- La eficacia concreta de las reglas agresivas deberá medirse cuando Xcode, WebKit y una conexión real estén disponibles.
- El icono definitivo puede evolucionar; v1 usará una identidad geométrica provisional propia.
