## ADDED Requirements

### Requirement: Clave fuera de fuentes
El valor de `YOUTUBE_DATA_KEY` SHALL permanecer fuera de archivos fuente y artefactos versionables.

#### Scenario: Generación local
- **WHEN** el script de configuración encuentra `YOUTUBE_DATA_KEY` en `.env`
- **THEN** genera un xcconfig ignorado sin imprimir el valor

### Requirement: Ausencia de filtraciones
La aplicación y las herramientas SHALL NOT incluir la clave en logs, telemetría, mensajes de error o documentación.

#### Scenario: Error de autenticación
- **WHEN** la API rechaza la clave
- **THEN** el mensaje describe el problema sin incluir URLs completas ni el valor de la clave

### Requirement: Configuración ausente
La aplicación SHALL detectar de manera explícita una clave no configurada.

#### Scenario: Primera ejecución sin secreto
- **WHEN** el build no contiene una clave válida
- **THEN** Búsqueda muestra instrucciones locales y no realiza la solicitud
