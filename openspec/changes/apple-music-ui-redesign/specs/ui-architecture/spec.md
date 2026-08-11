## ADDED Requirements

### Requirement: Tokens de sistema de diseño Apple Music Web

La aplicación SHALL emplear el sistema de tokens visuales de Apple Music Web en toda su interfaz: color de acento primario carmesí `#FA233C`, materiales traslúcidos glassmorphism (`ultraThinMaterial`), fondos oscuros profundos con bordes sutiles y tipografía estructurada basada en SF Pro.

#### Scenario: Aplicación de acento y materiales
- **WHEN** cualquier vista renderiza botones primarios, enlaces activos o indicadores de selección
- **THEN** utiliza el color de acento carmesí `#FA233C`
- **AND** las tarjetas y barras flotantes aplican materiales glassmorphism traslúcidos con bordes suaves de opacidad baja

### Requirement: Barra lateral y cabecera en pantallas amplias

En pantallas con clase de tamaño regular (iPad y macOS), la aplicación SHALL mostrar una barra lateral (Sidebar) con la marca de Apple Music / DiegoMusic, las secciones principales (Inicio, Búsqueda, Radio) y la biblioteca del usuario, acompañada de una cabecera fija con controles de navegación por historial.

#### Scenario: Visualización en tamaño regular
- **WHEN** la aplicación se ejecuta en `horizontalSizeClass == .regular`
- **THEN** se renderiza la barra lateral con accesos directos a Inicio, Búsqueda, Radio y Biblioteca
- **AND** la barra superior incluye los botones de historial y perfil/ajustes
