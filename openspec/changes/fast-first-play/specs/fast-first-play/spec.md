## ADDED Requirements

### Requirement: Descarga sin segunda extracción
El resolutor SHALL reutilizar la información obtenida en la resolución para descargar la caché M4A con `yt-dlp --load-info-json`, sin repetir la extracción de YouTube.

#### Scenario: Pista nueva resuelta
- **WHEN** `POST /v1/audio/resolve` resuelve una pista que no está en disco
- **THEN** la descarga en segundo plano invoca `yt-dlp` con `--load-info-json` y sin la URL de YouTube
- **AND** el archivo temporal de información se elimina al terminar, falle o no

#### Scenario: Sin información disponible
- **WHEN** se programa una descarga sin información de resolución
- **THEN** se usa la descarga completa con la misma selección de formato M4A/AAC que la resolución

### Requirement: Postproceso de una sola pasada
La descarga SHALL ejecutar `yt-dlp` con `--fixup never` y sin `-x`/`--audio-format`; el remux progresivo SHALL ser la única invocación de ffmpeg por pista.

#### Scenario: Descarga correcta
- **WHEN** `yt-dlp` termina con éxito
- **THEN** se ejecuta exactamente un ffmpeg (remux) antes del renombrado atómico

### Requirement: RAM acotada en el resolutor
El resolutor SHALL limitar a 2 las descargas simultáneas, y la caché de resolución en memoria SHALL NOT conservar la información de descarga.

#### Scenario: Ráfaga de pistas nuevas
- **WHEN** se programan más de 2 descargas a la vez
- **THEN** como máximo 2 procesos `yt-dlp` de descarga se ejecutan simultáneamente

#### Scenario: Entrada de caché de resolución
- **WHEN** `CachingAudioResolver` almacena una resolución
- **THEN** la entrada guardada tiene `download_info` igual a `None`

### Requirement: Precalentamiento desde el cliente
El cliente SHALL resolver en segundo plano hasta 2 pistas al abrir un álbum o una playlist, sin modificar la cola ni la pista actual.

#### Scenario: Abrir un álbum
- **WHEN** un álbum termina de cargar sus pistas
- **THEN** el cliente resuelve como máximo sus 2 primeras pistas que no sean la actual
- **AND** un fallo de esa resolución no se muestra al usuario
