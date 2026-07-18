## ADDED Requirements

### Requirement: Favoritos persistentes
DiegoMusic SHALL permitir añadir y quitar resultados como favoritos y conservarlos mediante Core Data entre ejecuciones.

#### Scenario: Marcar favorito
- **WHEN** el usuario marca un resultado que aún no está guardado
- **THEN** se crea una única entrada persistente con sus metadatos públicos

### Requirement: Playlists locales
DiegoMusic SHALL permitir crear playlists locales, añadir elementos, eliminarlos y conservar su orden.

#### Scenario: Añadir a playlist
- **WHEN** el usuario elige una playlist para un elemento
- **THEN** el elemento queda persistido al final de esa playlist sin duplicación accidental

### Requirement: Privacidad de biblioteca
La biblioteca SHALL permanecer local y SHALL NOT sincronizar ni enviar hábitos de reproducción a servicios propios.

#### Scenario: Uso sin cuenta
- **WHEN** el usuario usa favoritos y playlists
- **THEN** no se solicita inicio de sesión ni se envían esos datos fuera del dispositivo
