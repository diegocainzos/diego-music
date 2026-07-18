## ADDED Requirements

### Requirement: Reproducción nativa desde una sesión resuelta
DiegoMusic SHALL resolver el ID seleccionado mediante el servicio privado y SHALL reproducir la URL opaca resultante con una única instancia de AVPlayer.

#### Scenario: Selección correcta
- **WHEN** el usuario selecciona una canción y el resolutor devuelve una sesión válida
- **THEN** el cliente reemplaza la pista actual, inicia reproducción y actualiza el estado sin crear WKWebView

#### Scenario: Selección reemplazada
- **WHEN** el usuario selecciona otra canción mientras una resolución está pendiente
- **THEN** el cliente cancela o invalida la respuesta anterior y solo reproduce la última selección

#### Scenario: Error de resolución
- **WHEN** el resolutor no está configurado, no responde o rechaza la pista
- **THEN** el dock muestra un mensaje accionable que no contiene tokens ni URLs completas

### Requirement: Dock musical compacto
DiegoMusic SHALL mostrar un dock compacto sin vídeo con carátula, título, canal, estado y controles de reproducción. El usuario SHALL poder ampliar el dock para acceder al progreso y editar la cola sin sustituir la instancia de reproducción.

#### Scenario: Reproducción compacta
- **WHEN** una pista está activa y el dock permanece contraído
- **THEN** el audio continúa y los controles play/pause, anterior y siguiente permanecen disponibles

#### Scenario: Cambio de presentación
- **WHEN** el usuario amplía o contrae el dock
- **THEN** la pista, posición y estado de AVPlayer se conservan

### Requirement: Cola, progreso y finalización
El reproductor SHALL conservar la semántica existente de cola, permitir seek sobre una duración válida y avanzar a la siguiente pista al finalizar.

#### Scenario: Seek
- **WHEN** el usuario mueve el control de progreso a una fracción válida
- **THEN** AVPlayer busca la posición correspondiente dentro de la duración

#### Scenario: Fin de pista
- **WHEN** la pista finaliza y existe un elemento siguiente
- **THEN** el reproductor resuelve y reproduce el siguiente elemento

### Requirement: Segundo plano y controles del sistema en iPhone
DiegoMusic SHALL configurar una sesión de audio de reproducción, declarar background audio y publicar metadatos y comandos mediante MediaPlayer.

#### Scenario: Aplicación en segundo plano
- **WHEN** el usuario bloquea el iPhone o cambia de aplicación durante la reproducción
- **THEN** el audio continúa bajo la sesión `.playback`

#### Scenario: Control remoto
- **WHEN** el usuario pulsa play, pause, siguiente, anterior o seek desde el sistema o auriculares
- **THEN** DiegoMusic aplica el comando a la misma cola y AVPlayer activos

#### Scenario: Información de reproducción
- **WHEN** cambia la pista, posición, duración o velocidad
- **THEN** la pantalla bloqueada y el centro de control reciben metadatos actualizados

### Requirement: Configuración local segura
El cliente SHALL obtener la URL y el token del resolutor desde configuración local excluida de Git y SHALL validar la configuración antes de enviar una solicitud.

#### Scenario: Configuración completa
- **WHEN** existen una URL HTTPS válida y un token no vacío
- **THEN** el cliente habilita resolución remota y solo envía el token en Authorization

#### Scenario: Configuración incompleta
- **WHEN** falta la URL o el token
- **THEN** la app sigue iniciando y muestra que el resolutor necesita configuración al intentar reproducir
