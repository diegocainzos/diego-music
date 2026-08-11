## ADDED Requirements

### Requirement: Historial de navegación con botones Atrás y Adelante

La aplicación SHALL mantener un registro en tiempo real del historial de navegación que permita al usuario retroceder a la pantalla anterior mediante el botón Atrás `<` y avanzar a la pantalla siguiente mediante el botón Adelante `>`.

#### Scenario: Retroceder en el historial
- **WHEN** el usuario hace clic o toca el botón Atrás `<` teniendo elementos en la pila de historial anterior
- **THEN** la aplicación navega a la pantalla anterior
- **AND** habilita el botón Adelante `>`

#### Scenario: Botones de historial deshabilitados cuando no hay historial
- **WHEN** el usuario se encuentra en la pantalla inicial de la sesión sin historial previo
- **THEN** el botón Atrás `<` se muestra deshabilitado (opacidad reducida e inactivo)
