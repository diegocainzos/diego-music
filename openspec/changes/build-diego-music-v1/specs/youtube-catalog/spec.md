## ADDED Requirements

### Requirement: Búsqueda musical pública
El sistema SHALL consultar YouTube Data API v3 con una consulta codificada y devolver vídeos musicales públicos y reproducibles mediante el reproductor embebido.

#### Scenario: Búsqueda correcta
- **WHEN** el usuario introduce una consulta no vacía y la API responde correctamente
- **THEN** se muestran resultados con identificador, título, canal y miniatura

#### Scenario: Consulta vacía
- **WHEN** el usuario intenta buscar solo espacios
- **THEN** no se consume cuota y se mantiene un estado vacío explicativo

### Requirement: Separación de DTO y dominio
El sistema SHALL decodificar DTOs de YouTube y mapear únicamente resultados válidos a modelos de dominio independientes de la vista.

#### Scenario: Resultado sin vídeo
- **WHEN** la respuesta contiene un elemento sin `videoId`
- **THEN** el mapper lo omite sin invalidar los demás resultados

### Requirement: Errores y cuota
El sistema SHALL distinguir clave ausente, solicitud inválida, autenticación, cuota agotada, red y respuesta no válida.

#### Scenario: Cuota agotada
- **WHEN** YouTube responde con estado 403 y una razón de cuota
- **THEN** la UI muestra un mensaje de cuota agotada y permite reintentar más tarde
