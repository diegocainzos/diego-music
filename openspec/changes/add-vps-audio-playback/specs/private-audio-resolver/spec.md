## ADDED Requirements

### Requirement: Resolución autenticada por ID
El servicio SHALL aceptar solicitudes de resolución únicamente con un Bearer token válido y un identificador de vídeo YouTube válido de once caracteres. El servicio MUST construir internamente la URL de origen y MUST NOT aceptar URLs multimedia arbitrarias.

#### Scenario: Resolución autorizada
- **WHEN** un cliente autenticado envía un ID válido con una representación M4A/AAC disponible
- **THEN** el servicio devuelve una sesión de audio temporal con URL opaca, MIME y expiración

#### Scenario: Credencial inválida
- **WHEN** la solicitud omite el Bearer token o contiene uno incorrecto
- **THEN** el servicio responde 401 sin ejecutar el resolutor

#### Scenario: Identificador inválido
- **WHEN** la solicitud contiene un ID con longitud o caracteres no permitidos
- **THEN** el servicio responde 422 sin invocar `yt-dlp`

### Requirement: Selección de audio compatible
El servicio SHALL invocar `yt-dlp` sin shell, sin playlists y con argumentos fijos para seleccionar una representación de audio M4A/AAC compatible con AVPlayer. El servicio SHALL convertir fallos del proceso en errores API sanitizados.

#### Scenario: Pista compatible
- **WHEN** `yt-dlp` devuelve una representación M4A/AAC reproducible
- **THEN** el servicio conserva internamente su URL y cabeceras permitidas para la sesión

#### Scenario: Pista no disponible
- **WHEN** no existe una representación compatible o el origen rechaza la extracción
- **THEN** el servicio devuelve un error explícito sin incluir URLs, cookies, argumentos sensibles ni salida completa del proceso

### Requirement: Sesiones opacas y temporales
El servicio SHALL generar tokens criptográficamente aleatorios para cada sesión, almacenar la información upstream solo en memoria y rechazar sesiones ausentes o expiradas.

#### Scenario: Respuesta de resolución
- **WHEN** se crea una sesión correctamente
- **THEN** la respuesta no contiene la URL upstream ni las cabeceras utilizadas para obtenerla

#### Scenario: Sesión expirada
- **WHEN** un cliente solicita un token que excedió su TTL
- **THEN** el servicio responde 410 y elimina la sesión

### Requirement: Proxy de audio con rangos
El servicio SHALL soportar `GET` y `HEAD` sobre la URL opaca, reenviar peticiones HTTP Range al origen y propagar únicamente las cabeceras necesarias para reproducción y seeking.

#### Scenario: Petición parcial
- **WHEN** AVPlayer solicita un rango válido
- **THEN** el servicio reenvía `Range` y devuelve el estado 206 y las cabeceras de rango del upstream

#### Scenario: Petición HEAD
- **WHEN** AVPlayer inspecciona la pista mediante HEAD
- **THEN** el servicio devuelve metadatos de contenido sin transmitir el cuerpo

### Requirement: Estado operativo mínimo
El servicio SHALL exponer un endpoint de salud que no revele configuración ni compruebe contenido de usuario.

#### Scenario: Contenedor saludable
- **WHEN** se solicita `/health`
- **THEN** el servicio responde que está operativo sin requerir credenciales ni ejecutar `yt-dlp`
