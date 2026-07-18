# Especificación del proyecto: cliente educativo de YouTube Music

## 1. Resumen

Aplicación educativa multiplataforma para **iPhone, iPad y macOS**, desarrollada con Swift y SwiftUI. La aplicación ofrecerá una experiencia de exploración y reproducción musical inspirada funcionalmente en YouTube Music, utilizando las APIs y el reproductor oficial de YouTube.

El proyecto incorporará además un motor de privacidad y bloqueo de publicidad inspirado en la filosofía de **Brave Shields**, basado en reglas configurables y ejecutado localmente.

La aplicación es un proyecto privado de aprendizaje. No se distribuirá, comercializará ni publicará en la App Store.

## 2. Premisa de cumplimiento de YouTube

El responsable del proyecto ha revisado los términos aplicables de YouTube y YouTube Music en su país y ha confirmado que, para este caso de uso:

- está permitido desarrollar este cliente con fines educativos;
- está permitido utilizar el reproductor oficial de YouTube;
- está permitido aplicar el bloqueo de anuncios contemplado por este proyecto;
- no se publicará ni explotará comercialmente la aplicación;
- el proyecto se realizará dentro de los límites de los términos aplicables en su jurisdicción.

Por tanto, para el desarrollo de este repositorio se establece como **premisa y requisito del proyecto** que la implementación descrita es compatible con los términos de YouTube aplicables al responsable en su país. Si cambian los términos, la jurisdicción, el alcance o el modo de distribución, el responsable deberá revisar nuevamente esta premisa antes de continuar.

Esta declaración documenta la comprobación realizada por el responsable del proyecto; no constituye una evaluación jurídica independiente.

## 3. Objetivos

1. Aprender a construir una aplicación Apple multiplataforma con SwiftUI.
2. Integrar YouTube Data API para búsqueda y consulta de metadatos.
3. Integrar YouTube IFrame Player API como reproductor oficial.
4. Construir una interfaz musical nativa y adaptable.
5. Crear un motor de filtrado basado en reglas similar conceptualmente a Brave Shields.
6. Estudiar las diferencias entre iOS, iPadOS y macOS al integrar `WKWebView`.
7. Mantener credenciales, preferencias y datos personales protegidos.

## 4. Alcance funcional

### 4.1 Plataformas

- iPhone con iOS.
- iPad con iPadOS.
- Mac con macOS.
- Un único proyecto Xcode multiplataforma siempre que sea viable.
- Código compartido para modelos, servicios, navegación, reproducción y filtros.
- Adaptadores específicos únicamente cuando UIKit y AppKit lo requieran.

### 4.2 Navegación principal

- Inicio.
- Búsqueda.
- Biblioteca.
- Playlists.
- Historial local opcional.
- Mini reproductor persistente.
- Pantalla de reproducción completa.
- Ajustes y configuración del escudo de privacidad.

En iPhone se utilizará una navegación compacta. En iPad y macOS se priorizará `NavigationSplitView` y una presentación optimizada para pantallas grandes.

### 4.3 Búsqueda y catálogo

Se utilizará **YouTube Data API v3** para:

- buscar vídeos, canciones, artistas, canales y playlists;
- mostrar títulos, miniaturas, canales y metadatos disponibles;
- consultar elementos de playlists públicas;
- obtener información pública de vídeos y canales;
- transformar resultados de API en modelos internos independientes de la interfaz.

La aplicación tendrá estados explícitos de carga, contenido vacío, error de red y cuota agotada.

### 4.4 Reproducción

La reproducción se realizará mediante:

- `WKWebView`;
- YouTube IFrame Player API;
- una página HTML local controlada por la aplicación;
- comunicación entre Swift y JavaScript mediante `WKScriptMessageHandler` y evaluación controlada de JavaScript.

Funciones previstas:

- cargar un vídeo por su identificador;
- reproducir y pausar;
- avanzar y retroceder dentro de la cola;
- consultar el estado del reproductor;
- gestionar errores del reproductor;
- mostrar metadatos del elemento actual;
- mantener una cola de reproducción local;
- cambiar entre mini reproductor y pantalla completa sin perder el estado.

No se extraerán URLs de audio ni se sustituirá el reproductor oficial por un reproductor no autorizado.

### 4.5 Cola, biblioteca y playlists

- Cola de reproducción en memoria.
- Reordenación y eliminación de elementos.
- Favoritos locales.
- Playlists locales creadas por el usuario.
- Persistencia mediante SwiftData cuando sea compatible con los destinos mínimos.
- Posibilidad futura de sincronización mediante iCloud, desactivada en la primera versión.

### 4.6 Motor de privacidad y bloqueo

El módulo se denominará provisionalmente `PrivacyShield` y seguirá una filosofía inspirada en Brave:

- bloqueo local y activado por defecto;
- reglas transparentes y configurables;
- ausencia de seguimiento propio;
- ausencia de venta o envío de datos de navegación;
- procesamiento local siempre que sea posible;
- capacidad de desactivar el escudo para diagnosticar problemas;
- reglas estrictas y específicas para evitar romper la reproducción.

Implementación inicial:

- reglas compatibles con el formato aceptado por `WKContentRuleListStore`;
- filtros por patrón de URL, dominio, tipo de recurso y contexto de carga;
- compilación y caché de listas mediante `WKContentRuleListStore`;
- instalación de las reglas antes de cargar el contenido del reproductor;
- lista predeterminada incluida en el bundle;
- listas personalizadas importadas por el usuario;
- actualización manual de reglas desde una fuente configurada;
- interruptor global de activación;
- recarga controlada del reproductor después de cambiar reglas;
- diagnóstico local sin recopilar cookies, tokens ni contenido sensible.

Limitaciones que deberán contemplarse:

- `WKContentRuleList` opera mediante patrones y no comprende semánticamente el contenido;
- el iframe está sujeto al aislamiento de origen del navegador;
- Swift no puede manipular directamente el DOM interno de un iframe de YouTube;
- algunas solicitudes de publicidad y contenido pueden compartir infraestructura;
- una regla excesivamente amplia puede impedir la reproducción;
- no todas las solicitudes bloqueadas pueden contabilizarse directamente desde las APIs públicas de WebKit.

Las reglas reales se validarán de forma incremental. Antes de aplicarlas al reproductor oficial, el motor se probará con una página y recursos de prueba controlados por el proyecto.

## 5. Arquitectura propuesta

```text
MusicClient/
├── App/
│   ├── MusicClientApp.swift
│   ├── AppEnvironment.swift
│   └── RootView.swift
├── Core/
│   ├── Models/
│   ├── Networking/
│   ├── Persistence/
│   └── Utilities/
├── Features/
│   ├── Home/
│   ├── Search/
│   ├── Library/
│   ├── Playlists/
│   ├── Player/
│   └── Settings/
├── YouTube/
│   ├── YouTubeDataService.swift
│   ├── YouTubeEndpoint.swift
│   ├── YouTubeDTOs.swift
│   └── YouTubeMapper.swift
├── WebPlayer/
│   ├── YouTubePlayerView.swift
│   ├── PlayerCoordinator.swift
│   ├── PlayerMessage.swift
│   ├── iOSWebView.swift
│   ├── macOSWebView.swift
│   └── Resources/player.html
├── PrivacyShield/
│   ├── ContentBlocker.swift
│   ├── FilterRule.swift
│   ├── FilterListLoader.swift
│   ├── ShieldSettings.swift
│   └── Resources/default-rules.json
└── Tests/
    ├── UnitTests/
    └── UITests/
```

### 5.1 Principios de arquitectura

- SwiftUI como capa de presentación.
- Estado observable y aislado de las vistas.
- Concurrencia con `async/await`.
- Servicios definidos mediante protocolos para facilitar pruebas.
- DTOs de YouTube separados de los modelos de dominio.
- Inyección de dependencias sencilla mediante `AppEnvironment`.
- Código específico de plataforma protegido con compilación condicional.
- Ninguna clave secreta almacenada directamente en el código fuente.

## 6. Gestión de la clave de YouTube Data API

El responsable ya dispone de una clave de YouTube Data API.

Requisitos de seguridad:

- no escribir el valor de la clave en este documento;
- no incluirla directamente en archivos Swift versionados;
- almacenarla inicialmente en un archivo local de configuración excluido mediante `.gitignore`;
- proporcionar un archivo de ejemplo sin credenciales;
- restringir la clave desde Google Cloud tanto como permitan las aplicaciones cliente;
- no registrar la clave en consola, telemetría ni mensajes de error;
- asumir que una clave incluida en una aplicación cliente no puede considerarse totalmente secreta;
- considerar un backend intermediario si el proyecto deja de ser estrictamente local o educativo.

La clave se utilizará para búsquedas y metadatos. No será necesaria para el funcionamiento básico de YouTube IFrame Player API.

## 7. Privacidad

- Sin cuentas propias en la primera versión.
- Sin analítica ni telemetría de terceros.
- Sin servidores propios en la primera versión.
- Preferencias y biblioteca almacenadas localmente.
- No almacenar cookies, cabeceras de autenticación ni tokens en registros.
- El historial será local, opcional y eliminable.
- Todas las listas descargables deberán usar HTTPS.
- La aplicación mostrará claramente cuándo el escudo está activo.

## 8. Identidad visual

La aplicación puede inspirarse en los patrones de interacción de servicios musicales, pero tendrá:

- nombre propio;
- iconos y recursos propios;
- diseño visual propio;
- ausencia de logotipos que puedan inducir a pensar que es una aplicación oficial;
- atribuciones requeridas por las APIs utilizadas.

El objetivo es reproducir capacidades y aprender arquitectura, no representar falsamente una afiliación con YouTube o Google.

## 9. Pruebas

### 9.1 Pruebas unitarias

- codificación de consultas de búsqueda;
- decodificación de respuestas de YouTube Data API;
- transformación de DTOs a modelos de dominio;
- gestión de cuota y errores HTTP;
- operaciones sobre la cola;
- persistencia de biblioteca y ajustes;
- validación y carga de reglas;
- activación y desactivación del escudo.

### 9.2 Pruebas de integración

- carga del HTML local;
- comunicación JavaScript–Swift;
- carga de un identificador de vídeo;
- aplicación de una lista de contenido antes de navegar;
- recarga después de cambiar filtros;
- comportamiento independiente en iOS y macOS.

### 9.3 Entorno controlado del bloqueador

Se creará una página de prueba que contenga:

- recursos permitidos;
- recursos simulados que deban bloquearse;
- scripts, imágenes y solicitudes `fetch` de prueba;
- indicadores visibles para comprobar el resultado.

Esto permitirá validar el motor sin depender inicialmente de cambios externos en YouTube.

## 10. Fases de implementación

### Fase 1 — Base multiplataforma

- Crear proyecto Xcode para iOS, iPadOS y macOS.
- Añadir navegación y dependencias compartidas.
- Configurar credenciales locales y `.gitignore`.

### Fase 2 — Datos

- Implementar cliente de YouTube Data API.
- Añadir búsqueda y presentación de resultados.
- Manejar errores y límites de cuota.

### Fase 3 — Reproductor oficial

- Integrar `WKWebView` y el HTML local.
- Integrar IFrame Player API.
- Implementar mensajes Swift–JavaScript.
- Crear mini reproductor, pantalla completa y cola.

### Fase 4 — PrivacyShield

- Crear modelos de reglas y cargador.
- Compilar listas con WebKit.
- Construir el entorno de prueba controlado.
- Añadir ajustes, caché y recarga.
- Validar progresivamente filtros autorizados en el reproductor oficial.

### Fase 5 — Biblioteca y acabado

- Añadir SwiftData.
- Implementar favoritos y playlists locales.
- Mejorar accesibilidad, adaptación de interfaz y recuperación de errores.

## 11. Criterios de aceptación iniciales

La primera versión será considerada funcional cuando:

1. compile y se ejecute en un iPhone Simulator y en macOS;
2. permita buscar contenido mediante YouTube Data API;
3. muestre resultados con título y miniatura;
4. reproduzca un resultado mediante el reproductor oficial;
5. permita reproducir, pausar y cambiar de elemento en una cola;
6. compile e instale una lista de reglas de contenido;
7. demuestre el bloqueo en el entorno controlado;
8. permita activar y desactivar `PrivacyShield`;
9. no contenga la clave API ni otras credenciales en archivos versionados;
10. incluya pruebas unitarias para los componentes principales.

## 12. Decisiones pendientes

- Nombre definitivo de la aplicación y del bundle.
- Versiones mínimas de iOS, iPadOS y macOS.
- Estilo visual y sistema de diseño.
- Formato definitivo de las listas actualizables.
- Necesidad real de inicio de sesión de Google en fases futuras.
- Comportamiento disponible en segundo plano y con la pantalla bloqueada.
- Fuente concreta y mantenimiento de las reglas de bloqueo.

## 13. Instrucciones para la siguiente sesión

1. Leer este documento completo antes de implementar.
2. No solicitar ni imprimir públicamente el valor de la clave API.
3. Confirmar el nombre de la aplicación y los destinos mínimos.
4. Comprobar si ya existe un proyecto Xcode antes de crear uno.
5. Implementar primero un reproductor oficial sin filtros para disponer de una referencia funcional.
6. Desarrollar y probar `PrivacyShield` inicialmente contra el entorno controlado.
7. Mantener la compatibilidad de iPhone, iPad y macOS desde el inicio.
8. Documentar cualquier limitación detectada en WebKit o IFrame Player API.
