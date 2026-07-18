## ADDED Requirements

### Requirement: Compilación e instalación de reglas
PrivacyShield SHALL validar y compilar reglas compatibles con WKContentRuleListStore antes de cargar el contenido protegido.

#### Scenario: Lista válida
- **WHEN** la lista incluida contiene JSON válido
- **THEN** WebKit la compila, almacena e instala en la configuración del reproductor

#### Scenario: Lista inválida
- **WHEN** una lista personalizada no puede compilarse
- **THEN** el sistema conserva la última configuración funcional e informa el error localmente

### Requirement: Modos reversibles
PrivacyShield SHALL ofrecer desactivado, equilibrado y agresivo, y SHALL recargar de forma controlada el reproductor cuando cambie el modo.

#### Scenario: Recuperación por fallo
- **WHEN** el modo agresivo impide cargar o reproducir
- **THEN** el usuario puede volver a equilibrado o desactivado sin perder la cola

### Requirement: Bloqueo publicitario de mejor esfuerzo
El modo equilibrado SHALL bloquear hosts publicitarios de terceros conocidos y el modo agresivo SHALL añadir patrones específicos de anuncios de YouTube sin bloquear deliberadamente recursos multimedia principales.

#### Scenario: Recurso publicitario conocido
- **WHEN** la web solicita un recurso que coincide con una regla publicitaria activa
- **THEN** WebKit bloquea la carga antes de enviarla

### Requirement: Prueba controlada
El proyecto SHALL incluir una página con recursos permitidos y bloqueables que permita demostrar el resultado sin depender de YouTube.

#### Scenario: Regla de control
- **WHEN** la página solicita el recurso marcado para bloqueo
- **THEN** el indicador visible registra que el recurso no se cargó mientras los recursos permitidos sí lo hicieron

### Requirement: Diagnóstico privado
PrivacyShield SHALL NOT recopilar cookies, tokens, contenido sensible ni historial remoto.

#### Scenario: Diagnóstico
- **WHEN** se muestra el estado del escudo
- **THEN** solo se exponen modo, compilación y errores técnicos saneados
