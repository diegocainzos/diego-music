## ADDED Requirements

### Requirement: Reproducción mediante IFrame oficial
DiegoMusic SHALL cargar vídeos exclusivamente mediante YouTube IFrame Player API dentro de WKWebView y SHALL NOT extraer URLs multimedia.

#### Scenario: Carga de elemento
- **WHEN** el usuario selecciona un resultado reproducible
- **THEN** el bridge envía su `videoId` al reproductor oficial y actualiza el elemento actual

### Requirement: Controles y eventos
El bridge SHALL admitir cargar, reproducir, pausar y buscar, y SHALL traducir eventos de listo, estado, tiempo y error a mensajes tipados.

#### Scenario: Pausa desde Swift
- **WHEN** el coordinador envía el comando de pausa
- **THEN** JavaScript invoca `pauseVideo()` y devuelve el nuevo estado

#### Scenario: Mensaje no válido
- **WHEN** Swift recibe un mensaje con tipo o carga desconocidos
- **THEN** lo ignora de forma segura y no bloquea la aplicación

### Requirement: Cola local
El reproductor SHALL conservar una cola en memoria y permitir avance, retroceso, reordenación y eliminación.

#### Scenario: Final de elemento
- **WHEN** el reproductor informa que el vídeo terminó y existe un elemento siguiente
- **THEN** la cola selecciona y carga automáticamente el siguiente vídeo

#### Scenario: Eliminación del actual
- **WHEN** se elimina el elemento actual
- **THEN** la cola selecciona un vecino válido o queda vacía de forma consistente
