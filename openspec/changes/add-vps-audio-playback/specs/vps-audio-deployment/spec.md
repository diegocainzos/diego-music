## ADDED Requirements

### Requirement: Despliegue reproducible en contenedores
El repositorio SHALL incluir una imagen del resolutor y una composición para ejecutar el servicio y su terminación HTTPS en un VPS sin instalar dependencias de aplicación globalmente.

#### Scenario: Construcción limpia
- **WHEN** un operador construye la imagen desde un checkout limpio
- **THEN** la imagen instala versiones declaradas de Python, FastAPI, yt-dlp, sus componentes JavaScript y FFmpeg

#### Scenario: Reinicio del VPS
- **WHEN** el host o contenedor se reinicia
- **THEN** el servicio arranca automáticamente y reconstruye su almacén efímero vacío

### Requirement: Configuración mediante entorno
El despliegue SHALL recibir dominio, URL pública y token mediante variables no versionadas y SHALL proporcionar un archivo de ejemplo sin valores reales.

#### Scenario: Configuración válida
- **WHEN** el operador define dominio HTTPS, URL pública y un token suficientemente largo
- **THEN** los contenedores inician y el health check puede completarse

#### Scenario: Token ausente
- **WHEN** falta el token privado o no cumple la longitud mínima
- **THEN** el servicio falla al arrancar sin imprimir el valor recibido

### Requirement: Exposición HTTPS restringida
El reverse proxy SHALL publicar únicamente HTTPS hacia clientes, reenviar al resolutor dentro de la red de contenedores y evitar registrar tokens de stream en access logs por defecto.

#### Scenario: Acceso desde iPhone
- **WHEN** DiegoMusic accede al dominio configurado mediante HTTPS
- **THEN** el reverse proxy termina TLS y entrega la solicitud al servicio interno

#### Scenario: Puerto interno
- **WHEN** un cliente externo intenta acceder directamente al puerto del resolutor
- **THEN** el puerto no está publicado por la composición

### Requirement: Operación actualizable
La documentación SHALL explicar cómo rotar el token, actualizar la imagen de yt-dlp, comprobar salud y observar errores sanitizados.

#### Scenario: Cambio de YouTube
- **WHEN** la versión desplegada deja de resolver contenido compatible
- **THEN** el operador puede reconstruir y reiniciar el contenedor sin modificar ni reinstalar DiegoMusic, salvo que cambie el contrato API
